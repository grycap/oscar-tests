"""Read-only TLS certificate validation for OSCAR endpoints (issue #587).

Steps performed on an HTTPS endpoint URL:

* fetch the certificate chain the server actually presents for the host
  (SNI) -- prefer ``openssl s_client -showcerts``, fall back to the pure
  Python ``ssl`` module (leaf only);
* validate that the leaf certificate matches the host name
  (SubjectAltName, CN fallback) and that the presented chain is well
  formed (issuer/subject links and signatures);
* check the validity window: EXPIRED / EXPIRING_SOON (default threshold
  30 days) / still valid;
* check revocation through the sources the certificate advertises
  (OCSP first, then CRL distribution points), validating the revocation
  answer itself (signature, issuer, freshness) before trusting its
  verdict about the serial number.

Result statuses:  VALID, EXPIRED, EXPIRING_SOON, REVOKED, INDETERMINATE,
CHAIN_INVALID (name/chain problems), ERROR (fetch/network problems),
SKIPPED (non-HTTPS endpoint or SSL_VERIFY disabled).
"""

import datetime
import hashlib
import json
import socket
import ssl
import subprocess
import warnings
from ipaddress import ip_address
from urllib import error as urlerror
from urllib import parse as urlparse
from urllib import request as urlrequest

from cryptography import x509
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from cryptography.hazmat.primitives.asymmetric.ec import ECDSA
from cryptography.hazmat.primitives.asymmetric.padding import PKCS1v15
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.serialization import Encoding


def _utc(dt):
    """Return a timezone-aware UTC datetime."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=datetime.timezone.utc)
    return dt.astimezone(datetime.timezone.utc)


DEFAULT_TIMEOUT = 15
PEM_CERT = "-----BEGIN CERTIFICATE-----"


class TlsCheckError(Exception):
    """Failure to fetch or parse the certificate presented by an endpoint."""


def _parse_endpoint(url):
    parsed = urlparse.urlparse(url if "://" in url else "https://" + url)
    if parsed.scheme not in ("http", "https"):
        raise TlsCheckError(f"unsupported scheme in URL: {url!r}")
    host = parsed.hostname
    if not host:
        raise TlsCheckError(f"URL has no host: {url!r}")
    port = parsed.port if parsed.port is not None else (
        443 if parsed.scheme == "https" else 80)
    return parsed.scheme, host, port


def _certs_from_sclient_output(output):
    import re
    chain = [x509.load_pem_x509_certificate(cert_text.encode("utf-8"))
             for cert_text in re.findall(
                 PEM_CERT + r".*?-----END CERTIFICATE-----",
                 output, flags=re.S)]
    return chain


def _fetch_with_openssl(host, port, timeout=DEFAULT_TIMEOUT):
    cmd = ["openssl", "s_client", "-connect", f"{host}:{port}",
           "-servername", host, "-showcerts"]
    try:
        proc = subprocess.run(cmd, input=b"\n", capture_output=True,
                              timeout=timeout)
    except (subprocess.SubprocessError, OSError) as exc:
        raise TlsCheckError(f"openssl s_client on {host}:{port} failed: {exc}")
    chain = _certs_from_sclient_output(
        proc.stdout.decode("utf-8", errors="replace"))
    if not chain:
        raise TlsCheckError(
            f"no certificate presented by {host}:{port} (openssl s_client)")
    return chain, "openssl-sclient"


def _fetch_with_ssl_module(host, port, timeout=DEFAULT_TIMEOUT):
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    with socket.create_connection((host, port), timeout=timeout) as sock:
        with context.wrap_socket(sock, server_hostname=host) as tls:
            leaf_der = tls.getpeercert(binary_form=True)
    leaf = x509.load_der_x509_certificate(leaf_der)
    return [leaf], "ssl-module(leaf-only)"


def fetch_presentation(url, fetch=None, timeout=DEFAULT_TIMEOUT):
    """Fetch the certificate chain presented by ``url`` for its own SNI.

    Returns (host, port, chain, source).  ``fetch`` may be injected for
    tests: callable(url) -> (chain, source).
    """
    scheme, host, port = _parse_endpoint(url)
    if scheme != "https":
        raise TlsCheckError(f"{url} is not an HTTPS endpoint")
    if fetch is not None:
        chain, source = fetch(url)
        if not chain:
            raise TlsCheckError(f"no certificate presented by {host}:{port}")
        return host, port, chain, source
    try:
        return host, port, *(_fetch_with_openssl(host, port, timeout))
    except TlsCheckError as openssl_error:
        try:
            chain, source = _fetch_with_ssl_module(host, port, timeout)
        except (OSError, ssl.SSLError) as fallback_error:
            raise TlsCheckError(
                f"could not fetch certificate from {host}:{port} "
                f"(openssl: {openssl_error}; ssl: {fallback_error})") from openssl_error
        return host, port, chain, source


def _name_matches(leaf, host):
    from ipaddress import ip_address
    try:
        leaf.verify_hostname(host)
        return True
    except Exception:
        pass
    try:
        san = leaf.extensions.get_extension_for_class(
            x509.SubjectAlternativeName)
        for general in san.value:
            if isinstance(general, x509.DNSName):
                if general.value.lower() == host.lower():
                    return True
            elif isinstance(general, x509.IP):
                try:
                    if ip_address(str(general.value)) == ip_address(host):
                        return True
                except ValueError:
                    pass
        return False
    except x509.ExtensionNotFound:
        cn = leaf.subject.get_attributes_for_oid(
            x509.oid.NameOID.COMMON_NAME)
        return bool(cn) and cn[0].value.strip().lower() == host.lower()


def _verify_link(issuer_cert, cert):
    """Verify issuer/subject link and signature; return (ok, problem)."""
    from cryptography.exceptions import InvalidSignature
    if cert.issuer != issuer_cert.subject:
        return False, (f"issuer name mismatch: chain link subject "
                       f"{issuer_cert.subject!s} != cert issuer {cert.issuer!s}")
    pub = issuer_cert.public_key()
    try:
        if isinstance(pub, rsa.RSAPublicKey):
            pub.verify(cert.signature, cert.tbs_certificate_bytes,
                       PKCS1v15(), cert.signature_hash_algorithm)
        elif isinstance(pub, ec.EllipticCurvePublicKey):
            pub.verify(cert.signature, cert.tbs_certificate_bytes,
                       ECDSA(cert.signature_hash_algorithm))
        else:
            return None, "unsupported issuer key type; signature not verified"
    except InvalidSignature as exc:
        return False, f"signature verification failed: {exc}"
    except Exception as exc:
        return False, f"signature verification error: {exc}"
    return True, None


def _validate_chain(chain, host):
    """Return (problems) for name match, issuer links and signatures."""
    problems = []
    leaf = chain[0]
    if not _name_matches(leaf, host):
        problems.append(f"hostname {host!r} does not match certificate "
                        f"names ({leaf.subject.rfc4514_string()})")
    if len(chain) == 1:
        if leaf.subject == leaf.issuer:
            ok, problem = _verify_link(leaf, leaf)
        else:
            ok, problem = None, ("single non-self-signed certificate "
                                 "presented; issuer missing from chain")
        if ok is not True:
            problems.append(problem)
    else:
        for i in range(1, len(chain)):
            ok, problem = _verify_link(chain[i], chain[i - 1])
            if ok is not True:
                problems.append(problem)
        # The top of the chain does not have to be a self-issued root: real
        # servers commonly present partial chains, leaving the self-signed
        # root in the trust store (which we deliberately do not consult).
        # Every link *inside* the presented chain is verified above.
    return problems


def _date_status(leaf, threshold_seconds, now):
    """Return (status, days_until_expiry) for the validity window."""
    not_after = _utc(leaf.not_valid_after_utc)
    not_before = _utc(leaf.not_valid_before_utc)
    days = (not_after - now).total_seconds() / 86400.0
    if now > not_after:
        return "EXPIRED", days
    if (not_after - now).total_seconds() < threshold_seconds:
        return "EXPIRING_SOON", days
    return "VALID", days


def _cert_urls(cert):
    """Return ([ocsp_urls], [crl_urls]) advertised by one certificate."""
    ocsp_urls, crl_urls = [], []
    try:
        aia = cert.extensions.get_extension_for_class(
            x509.AuthorityInformationAccess)
        for ad in aia.value:
            if ad.access_method == x509.oid.AuthorityInformationAccessOID.OCSP:
                loc = ad.access_location
                if isinstance(loc, x509.UniformResourceIdentifier):
                    ocsp_urls.append(loc.value)
    except x509.ExtensionNotFound:
        pass
    try:
        dps = cert.extensions.get_extension_for_class(
            x509.CRLDistributionPoints)
        for dp in dps.value:
            if dp.full_name:
                for uri in dp.full_name:
                    if isinstance(uri, x509.UniformResourceIdentifier):
                        crl_urls.append(uri.value)
    except x509.ExtensionNotFound:
        pass
    return ocsp_urls, crl_urls


def _revocation_sources(chain):
    """[(method, url)] preferring OCSP, leaf first, then issuer certs."""
    sources, seen = [], set()
    for cert in chain:
        ocsp_urls, crl_urls = _cert_urls(cert)
        found = False
        for method, urls in (("ocsp", ocsp_urls), ("crl", crl_urls)):
            for url in urls:
                key = (method, url)
                if key not in seen:
                    seen.add(key)
                    sources.append(key)
                    found = True
        if found:
            break
    return sources


def default_http_fetch(url, body=None, timeout=DEFAULT_TIMEOUT):
    """GET or POST ``url``; return (http_status, response_bytes)."""
    headers = {"User-Agent": "oscar-tests/tls-cert-check (issue #587)"}
    if body is not None:
        data = body
        headers["Content-Type"] = "application/ocsp-request"
    else:
        data = None
    request = urlrequest.Request(url, data=data, headers=headers)
    with urlrequest.urlopen(request, timeout=timeout) as response:
        return response.status, response.read()


SKEW = datetime.timedelta(minutes=5)


_REASON_LABELS = {
    "unspecified": "Unspecified",
    "key_compromise": "Key Compromise",
    "ca_compromise": "CA Compromise",
    "affiliation_changed": "Affiliation Changed",
    "superseded": "Superseded",
    "cessation_of_operation": "Cessation Of Operation",
    "certificate_hold": "Certificate Hold",
    "privilege_withdrawn": "Privilege Withdrawn",
    "aa_compromise": "AA Compromise",
    "remove_from_crl": "Remove From CRL",
}


def _reason_label(value):
    """Legible label for a PKIX revocation reason value."""
    reason = getattr(value, "reason", value)
    if reason is not None and hasattr(reason, "name"):
        return _REASON_LABELS.get(reason.name, str(reason))
    return str(value)


def _ocsp_check(url, cert, issuer, now, http_fetch, timeout):
    from cryptography.x509 import ocsp
    try:
        request = (ocsp.OCSPRequestBuilder()
                   .add_certificate(cert, issuer,
                                    cert.signature_hash_algorithm)
                   .build())
        body = request.public_bytes(Encoding.DER)
    except Exception as exc:
        return ("invalid", None, f"OCSP request could not be built: {exc}")
    try:
        status_code, data = http_fetch(url, body=body, timeout=timeout)
    except Exception as exc:
        return ("invalid", None, f"OCSP request to {url} failed: {exc}")
    if status_code != 200:
        return ("invalid", None, f"OCSP endpoint {url} returned HTTP {status_code}")
    try:
        response = ocsp.load_der_ocsp_response(data)
    except Exception as exc:
        return ("invalid", None, f"OCSP answer from {url} is not valid: {exc}")
    if response.response_status != ocsp.OCSPResponseStatus.SUCCESSFUL:
        return ("invalid", None,
                f"OCSP response status is {response.response_status}")
    pub = issuer.public_key()
    try:
        if isinstance(pub, rsa.RSAPublicKey):
            pub.verify(response.signature, response.tbs_response_bytes,
                       PKCS1v15(), response.signature_hash_algorithm)
        elif isinstance(pub, ec.EllipticCurvePublicKey):
            pub.verify(response.signature, response.tbs_response_bytes,
                       ECDSA(response.signature_hash_algorithm))
        else:
            return ("invalid", None, "unsupported key type of OCSP signer")
    except Exception as exc:
        return ("invalid", None, f"OCSP answer signature invalid: {exc}")
    digest = None
    for length, name in ((20, "sha1"), (32, "sha256"),
                         (48, "sha384"), (64, "sha512")):
        if len(response.issuer_name_hash) == length:
            digest = hashlib.new(name)
            digest.update(issuer.subject.public_bytes(Encoding.DER))
            break
    if digest is None or digest.digest() != response.issuer_name_hash:
        return ("invalid", None,
                "issuer_name_hash does not match the issuing certificate")
    if (response.serial_number != cert.serial_number or
            response.issuer_key_hash != request.issuer_key_hash):
        return ("invalid", None,
                "response CertID does not match the requested certificate")
    this_update = _utc(response.this_update_utc)
    if this_update is not None and this_update > now + SKEW:
        return ("invalid", None, f"OCSP this_update {this_update:%m/%d/%Y} "
                                 "is in the future")
    next_update = _utc(response.next_update_utc)
    if next_update is not None and next_update < now:
        return ("invalid", None,
                f"OCSP answer expired on {next_update:%m/%d/%Y}")
    status = response.certificate_status
    if status == ocsp.OCSPCertStatus.GOOD:
        return ("ok", "good",
                "OCSP (signed by the issuer) reports the certificate GOOD")
    if status == ocsp.OCSPCertStatus.REVOKED:
        return ("ok", "revoked", "OCSP reports REVOKED: "
                + _ocsp_revocation_details(response))
    return ("invalid", None, f"OCSP status {status} is not actionable")


def _ocsp_revocation_details(response):
    parts = []
    if response.revocation_reason is not None:
        parts.append(f"reason: {_reason_label(response.revocation_reason)}")
    when = response.revocation_time_utc
    if when is not None:
        parts.append(f"since {_utc(when):%Y-%m-%d}")
    return ", ".join(parts) if parts else "no time or reason given"


def _crl_entry_reason(entry):
    for ext in entry.extensions:
        if ext.oid == x509.oid.CRLEntryExtensionOID.CRL_REASON:
            flags = getattr(ext.value, "value", ext.value)
            return f" (reason: {_reason_label(flags)})"
    return ""


def _crl_check(url, cert, issuer, now, http_fetch, timeout):
    try:
        status_code, data = http_fetch(url, timeout=timeout)
    except Exception as exc:
        return ("invalid", None, f"CRL fetch from {url} failed: {exc}")
    if status_code != 200:
        return ("invalid", None, f"CRL endpoint {url} returned HTTP {status_code}")
    try:
        crl = x509.load_der_x509_crl(data)
    except Exception:
        try:
            crl = x509.load_pem_x509_crl(data)
        except Exception as exc:
            return ("invalid", None,
                    f"CRL at {url} is not a valid structure: {exc}")
    pub = issuer.public_key()
    try:
        signed = crl.is_signature_valid(pub)
    except Exception as exc:
        return ("invalid", None, f"CRL signature verification error: {exc}")
    if not signed:
        return ("invalid", None, "CRL signature is not valid")
    if crl.issuer != issuer.subject:
        return ("invalid", None,
                f"CRL issuer ({crl.issuer.rfc4514_string()}) does not match "
                "the issuing certificate")
    next_update = _utc(crl.next_update_utc)
    if next_update is not None and next_update < now:
        return ("invalid", None, f"CRL expired on {next_update:%Y-%m-%d}")
    entry = crl.get_revoked_certificate_by_serial_number(cert.serial_number)
    if entry is not None:
        revoke = _utc(entry.revocation_date_utc)
        return ("ok", "revoked", f"CRL lists the certificate as revoked "
                f"since {revoke:%Y-%m-%d}{_crl_entry_reason(entry)}")
    return ("ok", "good",
            f"CRL (last updated {_utc(crl.last_update_utc):%Y-%m-%d}) does "
            "not list this serial; not revoked")


DEFAULT_EXPIRING_THRESHOLD = 2592000  # 30 days


def check_revocation(chain, now, http_fetch=None, timeout=DEFAULT_TIMEOUT):
    """Check every revocation source the chain advertises; aggregate.

    Returns a dict with ``status`` (None, REVOKED or INDETERMINATE), a
    ``message`` for the non-None cases and the per-endpoint ``evidence``.
    """
    leaf = chain[0]
    http_fetch = http_fetch or default_http_fetch
    if len(chain) > 1:
        issuer = chain[1]
    elif leaf.subject == leaf.issuer:
        issuer = leaf
    else:
        return {"advertised": False, "status": None, "evidence": [],
                "detail": "issuer certificate not presented; revocation "
                          "cannot be verified"}
    sources = _revocation_sources(chain)
    if not sources:
        return {"advertised": False, "status": None, "evidence": [],
                "detail": "cert advertises neither OCSP nor CRL URLs"}
    evidence = []
    for method, url in sources:
        if method == "ocsp":
            outcome, verdict, detail = _ocsp_check(
                url, leaf, issuer, now, http_fetch, timeout)
        else:
            outcome, verdict, detail = _crl_check(
                url, leaf, issuer, now, http_fetch, timeout)
        evidence.append({"method": method, "url": url, "outcome": outcome,
                         "verdict": verdict, "detail": detail})
    described = "; ".join(f"{e['method'].upper()} {e['url']}: {e['detail']}"
                          for e in evidence)
    good = [e for e in evidence if e["outcome"] == "ok"]
    revoked = [e for e in good if e["verdict"] == "revoked"]
    if revoked:
        e = revoked[0]
        message = (f"REVOKED: certificate serial {leaf.serial_number} is "
                   f"revoked according to a valid {e['method'].upper()} "
                   f"answer from {e['url']} -- {e['detail']}")
        return {"advertised": True, "status": "REVOKED", "message": message,
                "evidence": evidence, "detail": e["detail"]}
    if good:
        return {"advertised": True, "status": None, "evidence": evidence,
                "detail": described}
    message = (f"INDETERMINATE: no trustworthy revocation evidence for "
               f"certificate serial {leaf.serial_number}; {described}")
    return {"advertised": True, "status": "INDETERMINATE",
            "message": message, "evidence": evidence, "detail": described}


def check_certificate(url, expiring_threshold=DEFAULT_EXPIRING_THRESHOLD,
                      now=None, fetch=None, http_fetch=None,
                      timeout=DEFAULT_TIMEOUT):
    """Full read-only TLS certificate check for one endpoint. Returns dict."""
    now = now or datetime.datetime.now(datetime.timezone.utc)
    now = _utc(now)
    result = {"url": url, "host": None, "port": None, "status": "ERROR",
              "message": "", "evidence": []}
    try:
        scheme, host, port = _parse_endpoint(url)
    except TlsCheckError as exc:
        result["message"] = f"ERROR: {exc}"
        return result
    result["host"], result["port"] = host, port
    if scheme != "https":
        result["status"] = "SKIPPED"
        result["message"] = f"SKIPPED: {url} is not an HTTPS endpoint"
        return result
    try:
        host, port, chain, source = fetch_presentation(
            url, fetch=fetch, timeout=timeout)
    except TlsCheckError as exc:
        result["message"] = (f"ERROR: could not fetch certificate from "
                             f"{host}:{port}: {exc}")
        return result
    leaf = chain[0]
    result.update(
        host=host, port=port, source=source,
        subject=leaf.subject.rfc4514_string(), issuer=leaf.issuer.rfc4514_string(),
        serial=leaf.serial_number,
        fingerprint=leaf.fingerprint(hashes.SHA256()).hex(),
        not_before=_utc(leaf.not_valid_before_utc).isoformat(),
        not_after=_utc(leaf.not_valid_after_utc).isoformat())
    problems = _validate_chain(chain, host)
    if problems:
        result["status"] = "INVALID"
        result["message"] = "INVALID: " + "; ".join(problems)
        return result
    date_status, days = _date_status(leaf, expiring_threshold, now)
    result["days_until_expiry"] = round(days, 3)
    rev = check_revocation(chain, now, http_fetch=http_fetch, timeout=timeout)
    result["evidence"] = rev["evidence"]
    if rev["status"] == "REVOKED":
        result["status"], result["message"] = "REVOKED", rev["message"]
    elif rev["status"] == "INDETERMINATE":
        result["status"], result["message"] = "INDETERMINATE", rev["message"]
    else:
        result["status"] = date_status
        note = (f" [revocation check: {rev['detail']}]"
                if rev["advertised"] else f" [note: {rev['detail']}]")
        if date_status == "EXPIRED":
            result["message"] = (f"EXPIRED: certificate not valid after "
                                 f"{result['not_after']}{note}")
        elif date_status == "EXPIRING_SOON":
            result["message"] = (f"EXPIRING_SOON: certificate expires on "
                                 f"{result['not_after']}, only {days:.1f} days "
                                 f"left (threshold {expiring_threshold // 86400} "
                                 f"days){note}")
        else:
            result["message"] = (f"VALID: host {host} matches, chain verified, "
                                 f"valid until {result['not_after']} "
                                 f"({days:.1f} days left){note}")
    return result


try:
    from robot.api import SkipExecution, logger
    from robot.api.deco import keyword
    _ROBOT_AVAILABLE = True
except ImportError:
    _ROBOT_AVAILABLE = False


def _skip(message):
    if _ROBOT_AVAILABLE:
        raise SkipExecution(message)


class TlsCertificateLibrary:
    """Read-only TLS certificate verification for OSCAR endpoints (issue #587).

    A certificate that is expired, expires in less than 30 days, or is
    revoked (CRL or OCSP evidence) fails the suite; an unusable revocation
    lookup also fails (INDETERMINATE) with a distinct message.
    """

    @keyword(name="Check Tls Certificate")
    def check_tls_certificate(self, url,
                              threshold_seconds=DEFAULT_EXPIRING_THRESHOLD):
        """Return a result dict for ``url``: status, message, evidence, ...

        Statuses: VALID, EXPIRED, EXPIRING_SOON, REVOKED, INDETERMINATE,
        INVALID (name/chain problems), ERROR (fetch), SKIPPED (non-HTTPS).
        """
        result = check_certificate(url,
                                   expiring_threshold=int(threshold_seconds))
        logger.info(f"TLS check of {url} -> {result['status']}")
        logger.info(result["message"])
        return result

    @keyword(name="Endpoint Certs Are Valid")
    def endpoint_certs_are_valid(self, endpoint, ssl_verify="${SSL_VERIFY}",
                                 threshold_seconds=DEFAULT_EXPIRING_THRESHOLD):
        """Fail the suite unless the endpoint certificate is VALID.

        Skips (no failure) when the endpoint is undefined, not an HTTPS
        URL, or ``SSL_VERIFY`` is false (local kind setups).
        """
        url = str(endpoint).strip()
        if not url or url.upper() == "NONE":
            _skip("no endpoint URL configured (variable undefined or empty)")
        if str(ssl_verify).strip().lower() in ("false", "no", "0"):
            _skip(f"SSL_VERIFY is {ssl_verify}; TLS check disabled for this "
                  "endpoint")
        result = self.check_tls_certificate(url, threshold_seconds)
        if result["status"] == "SKIPPED":
            _skip(result["message"])
        if result["status"] != "VALID":
            message = (f"certificate problem for {url} "
                       f"[serial {result.get('serial')}, valid until "
                       f"{result.get('not_after')}]: {result['message']}")
            logger.warn(message)
            raise AssertionError(message)


# Robot Framework resolves a path-based library file to a class only when
# a class name equals the module name; otherwise it exposes the
# module-level functions instead.  Alias the library class under the
# module name so that the ``Check Tls Certificate`` and
# ``Endpoint Certs Are Valid`` keywords (issue #587) are the ones
# registered.
tls_certificate = TlsCertificateLibrary  # noqa: N816
