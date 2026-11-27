"""Offline pytest coverage for robot_libs/tls_certificate (issue #587).

All endpoints are fake: the TLS presentation and the OCSP/CRL answers are
injected, so the whole matrix runs without network access.
"""
import datetime
import os
import sys

import pytest
from cryptography import x509
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.serialization import Encoding

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from robot_libs import tls_certificate as tls  # noqa: E402
from cryptography.x509 import ocsp  # noqa: E402

NOW = datetime.datetime(2026, 11, 26, 9, 0, tzinfo=datetime.timezone.utc)
DAY = datetime.timedelta(days=1)


def mk_ca(name="Test CA"):
    key = ec.generate_private_key(ec.SECP256R1())
    name_obj = x509.Name([x509.NameAttribute(x509.oid.NameOID.COMMON_NAME, name)])
    cert = (x509.CertificateBuilder()
            .subject_name(name_obj).issuer_name(name_obj)
            .public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(NOW - DAY)
            .not_valid_after(NOW + 365 * DAY)
            .add_extension(x509.BasicConstraints(ca=True, path_length=None),
                           critical=True)
            .sign(key, hashes.SHA256()))
    return cert, key, name_obj


def mk_leaf(ca_cert, ca_key, ca_name, san="api.test",
            serial=12345, not_before=None, not_after=None,
            aia=None, crldp=None, cn=None):
    leaf_key = ec.generate_private_key(ec.SECP256R1())
    builder = (x509.CertificateBuilder()
               .subject_name(x509.Name(
                   [x509.NameAttribute(x509.oid.NameOID.COMMON_NAME,
                                       cn or san)]))
               .issuer_name(ca_name)
               .public_key(leaf_key.public_key())
               .serial_number(serial)
               .not_valid_before(not_before or (NOW - DAY))
               .not_valid_after(not_after or (NOW + 365 * DAY)))
    if san:
        builder = builder.add_extension(
            x509.SubjectAlternativeName([x509.DNSName(san)]), critical=False)
    if aia is not None:
        builder = builder.add_extension(aia, critical=False)
    if crldp is not None:
        builder = builder.add_extension(crldp, critical=False)
    return builder.sign(ca_key, hashes.SHA256())


def ocsp_ad(url):
    return x509.AuthorityInformationAccess([
        x509.AccessDescription(
            x509.oid.AuthorityInformationAccessOID.OCSP,
            x509.UniformResourceIdentifier(url))])


def crl_dp(url):
    return x509.CRLDistributionPoints([
        x509.DistributionPoint(
            [x509.UniformResourceIdentifier(url)], None, None, None)])


def build_ocsp(cert, ca, ca_key, status, this_update=None, next_update=None,
               rev_time=None, reason=None):
    builder = ocsp.OCSPResponseBuilder().add_response(
        cert, ca, hashes.SHA256(), status,
        this_update or (NOW - DAY), next_update or (NOW + 7 * DAY),
        rev_time, reason)
    builder = builder.responder_id(ocsp.OCSPResponderEncoding.HASH, ca)
    return builder.sign(ca_key, hashes.SHA256())


def build_crl(ca, ca_key, ca_name, serials=(), last_update=None,
              next_update=None, with_reason=True, reason=None):
    entries = []
    for serial in serials:
        if with_reason:
            flags = reason or x509.ReasonFlags.superseded
            ext = x509.CRLReason(flags)
            entries.append(
                x509.RevokedCertificateBuilder(
                    serial, NOW - DAY,
                    extensions=[x509.Extension(
                        x509.oid.CRLEntryExtensionOID.CRL_REASON, False,
                        ext)]).build())
        else:
            entries.append(
                x509.RevokedCertificateBuilder(serial, NOW - DAY).build())
    crl = (x509.CertificateRevocationListBuilder(
        issuer_name=ca_name,
        last_update=last_update or (NOW - DAY),
        next_update=next_update or (NOW + 7 * DAY),
        revoked_certificates=entries).sign(ca_key, hashes.SHA256()))
    return crl.public_bytes(Encoding.DER)


class FakeTransport:
    """Maps url -> bytes; missing entries raise (endpoint unreachable)."""

    def __init__(self):
        self.urls = {}

    def add(self, url, data, status=200):
        self.urls[url] = (status, data)

    def fetch(self, url, body=None, timeout=15):
        if url not in self.urls:
            raise ConnectionError(f"endpoint {url} unreachable")
        return self.urls[url]


def make_presentation(leaf, ca):
    """Parsed certs + source, the shape real fetches return."""
    return ([leaf, ca], "test-injection")


def check(url, presentation, trans, now=NOW, threshold=2592000):
    """Run check_certificate with injected presentation + transport."""
    def fetch(u):
        return presentation
    return tls.check_certificate(
        url, fetch=fetch, http_fetch=trans.fetch, now=now,
        expiring_threshold=threshold)


def make_ca_pair(name="Test CA"):
    return mk_ca(name)


def basic_trans(ca, ca_key, ca_name, leaf, ocsp_status=None,
                crl_serials=(), crl_next=None):
    """OCSP + CRL endpoints alive and healthy ('good' evidence)."""
    trans = FakeTransport()
    if ocsp_status is None:
        ocsp_status = ocsp.OCSPCertStatus.GOOD
    with_reason = ocsp_status == ocsp.OCSPCertStatus.REVOKED
    resp = build_ocsp(leaf, ca, ca_key, ocsp_status,
                      rev_time=(NOW - 3 * DAY) if with_reason else None,
                      reason=x509.ReasonFlags.superseded if with_reason else None)
    trans.add(OCSP_URL, resp.public_bytes(Encoding.DER))
    trans.add(CRL_URL,
              build_crl(ca, ca_key, ca_name, serials=crl_serials,
                        next_update=crl_next))
    return trans


URL = "https://api.test"
SERIAL = 12345


OCSP_URL = "https://ocsp.test/ocsp"
CRL_URL = "https://cacert.test/crl/1.crl"


def bare(ca_cert, ca_key, ca_name, **leaf_kw):
    no_ocsp = leaf_kw.pop("no_ocsp", False)
    no_crl = leaf_kw.pop("no_crl", False)
    aia = None if no_ocsp else ocsp_ad(OCSP_URL)
    crldp = None if no_crl else crl_dp(CRL_URL)
    leaf_kw.setdefault("aia", aia)
    leaf_kw.setdefault("crldp", crldp)
    leaf = mk_leaf(ca_cert, ca_key, ca_name, serial=SERIAL, **leaf_kw)
    return leaf, make_presentation(leaf, ca_cert)


def test_valid_chain_passes():
    ca, ca_key, ca_name = make_ca_pair()
    leaf, pres = bare(ca, ca_key, ca_name)
    trans = basic_trans(ca, ca_key, ca_name, leaf)
    r = check(URL, pres, trans)
    assert r["status"] == "VALID", r["message"]
    assert "VALID:" in r["message"]
    assert r["not_after"].startswith("2027-11")


def test_expired_fails():
    ca, ca_key, ca_name = make_ca_pair()
    leaf, pres = bare(ca, ca_key, ca_name,
                      not_before=NOW - 10 * DAY,
                      not_after=NOW - 5 * DAY)
    trans = basic_trans(ca, ca_key, ca_name, leaf)
    r = check(URL, pres, trans)
    assert r["status"] == "EXPIRED", r["message"]
    assert r["message"].startswith("EXPIRED:")


def test_expiring_soon_fails_at_29_days():
    ca, ca_key, ca_name = make_ca_pair()
    leaf, pres = bare(ca, ca_key, ca_name,
                      not_after=NOW + 29 * DAY)
    trans = basic_trans(ca, ca_key, ca_name, leaf)
    r = check(URL, pres, trans)
    assert r["status"] == "EXPIRING_SOON", r["message"]
    assert r["message"].startswith("EXPIRING_SOON:")


def test_not_expiring_in_31_days_is_valid_datewise():
    ca, ca_key, ca_name = make_ca_pair()
    leaf, pres = bare(ca, ca_key, ca_name,
                      not_after=NOW + 31 * DAY)
    trans = basic_trans(ca, ca_key, ca_name, leaf)
    r = check(URL, pres, trans)
    assert r["status"] == "VALID", r["message"]
    assert r["days_until_expiry"] == 31


def test_date_valid_but_revoked_fails_revoked():
    # a date-valid certificate must NOT pass because of its date alone
    ca, ca_key, ca_name = make_ca_pair()
    leaf, pres = bare(ca, ca_key, ca_name, no_crl=True)
    trans = basic_trans(ca, ca_key, ca_name, leaf,
                        ocsp_status=ocsp.OCSPCertStatus.REVOKED)
    r = check(URL, pres, trans)
    assert r["status"] == "REVOKED", r["message"]
    assert "EXPIRED" not in r["status"]


def test_hostname_mismatch_is_invalid():
    ca, ca_key, ca_name = make_ca_pair()
    leaf, pres = bare(ca, ca_key, ca_name, san="other.test")
    r = check(URL, pres, FakeTransport())
    assert r["status"] == "INVALID", r["message"]
    assert "hostname" in r["message"]


def test_incomplete_chain_is_invalid():
    ca, ca_key, ca_name = make_ca_pair()
    leaf = mk_leaf(ca, ca_key, ca_name, serial=SERIAL)
    r = check(URL, ([leaf], "test-injection"), FakeTransport())
    assert r["status"] == "INVALID", r["message"]
    assert "issuer" in r["message"]


def test_non_https_is_skipped():
    r = check("http://api.test", ([], "x"), FakeTransport())
    assert r["status"] == "SKIPPED"
    assert r["message"].startswith("SKIPPED:")


def test_no_revocation_sources_advertised_is_date_verdict():
    ca, ca_key, ca_name = make_ca_pair()
    leaf, pres = bare(ca, ca_key, ca_name, no_ocsp=True, no_crl=True)
    r = check(URL, pres, FakeTransport())
    assert r["status"] == "VALID", r["message"]
    assert "neither OCSP nor CRL" in r["message"]


def test_revoked_via_crl():
    ca, ca_key, ca_name = make_ca_pair()
    leaf, pres = bare(ca, ca_key, ca_name, no_ocsp=True)
    trans = basic_trans(ca, ca_key, ca_name, leaf, crl_serials=[SERIAL])
    r = check(URL, pres, trans)
    assert r["status"] == "REVOKED", r["message"]
    assert r["message"].startswith("REVOKED:")
    assert "CRL" in r["message"]
    assert "Superseded" in r["message"]
    assert "2026-11-25" in r["message"]


def test_revoked_via_ocsp():
    ca, ca_key, ca_name = make_ca_pair()
    leaf, pres = bare(ca, ca_key, ca_name, no_crl=True)
    trans = basic_trans(ca, ca_key, ca_name, leaf,
                        ocsp_status=ocsp.OCSPCertStatus.REVOKED)
    r = check(URL, pres, trans)
    assert r["status"] == "REVOKED", r["message"]
    assert "OCSP" in r["message"]
    assert "Superseded" in r["message"]


def test_crl_unreachable_is_indeterminate():
    ca, ca_key, ca_name = make_ca_pair()
    leaf, pres = bare(ca, ca_key, ca_name, no_ocsp=True)
    r = check(URL, pres, FakeTransport())
    assert r["status"] == "INDETERMINATE", r["message"]
    assert r["message"].startswith("INDETERMINATE:")


def test_crl_bad_signature_is_indeterminate():
    ca, ca_key, ca_name = make_ca_pair()
    leaf, pres = bare(ca, ca_key, ca_name, no_ocsp=True)
    # CRL structurally valid but signed by the wrong key
    crl_wrong = build_crl_for_wrong_key(ca, ca_key, ca_name,
                                        serials=[SERIAL])
    trans = FakeTransport()
    trans.add("https://cacert.test/crl/1.crl", crl_wrong)
    r = check(URL, pres, trans)
    assert r["status"] == "INDETERMINATE", r["message"]
    assert "CRL" in r["message"]


def build_crl_for_wrong_key(ca, ca_key, ca_name, serials=()):
    """CRL signed by a CA whose subject is the expected issuer but whose
    key does not sign the real certificate (attacker CA)."""
    attacker, attacker_key, _ = mk_ca("Test CA")
    return build_crl(ca, attacker_key, ca_name, serials=serials)


def test_crl_expired_is_indeterminate():
    ca, ca_key, ca_name = make_ca_pair()
    leaf, pres = bare(ca, ca_key, ca_name, no_ocsp=True)
    trans = FakeTransport()
    trans.add("https://cacert.test/crl/1.crl",
              build_crl(ca, ca_key, ca_name,
                        next_update=NOW - DAY))
    r = check(URL, pres, trans)
    assert r["status"] == "INDETERMINATE", r["message"]
    assert "expired" in r["message"]


def test_ocsp_unreachable_is_indeterminate():
    ca, ca_key, ca_name = make_ca_pair()
    leaf, pres = bare(ca, ca_key, ca_name, no_crl=True)
    r = check(URL, pres, FakeTransport())
    assert r["status"] == "INDETERMINATE", r["message"]
    assert "OCSP" in r["message"]


def test_ocsp_bad_answer_is_indeterminate():
    ca, ca_key, ca_name = make_ca_pair()
    leaf, pres = bare(ca, ca_key, ca_name, no_crl=True)
    trans = FakeTransport()
    trans.add("https://ocsp.test/ocsp", b"not an OCSP response")
    r = check(URL, pres, trans)
    assert r["status"] == "INDETERMINATE", r["message"]


def test_crl_issuer_mismatch_is_indeterminate():
    ca, ca_key, ca_name = make_ca_pair()
    other, other_key, other_name = mk_ca("Other CA")
    leaf, pres = bare(ca, ca_key, ca_name, no_ocsp=True)
    trans = FakeTransport()
    trans.add("https://cacert.test/crl/1.crl",
              build_crl(other, other_key, other_name))
    r = check(URL, pres, trans)
    assert r["status"] == "INDETERMINATE", r["message"]
