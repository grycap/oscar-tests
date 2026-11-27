# TLS certificate verification suite (issue #587)

**Read-only** suite for the OSCAR endpoints: it creates no cluster
resources and requires no authentication. The endpoint and the dashboard
must present their own TLS certificate, not expired (or about to expire)
and not revoked.

## What the test checks

It runs the following for each URL and fails if anything is invalid:

1. **Capture** of the presented chain with SNI (`openssl s_client
   -showcerts`, with a *fallback* to the `ssl` module, leaf only).
2. **Name**: the host must appear in the leaf certificate's SAN (or CN).
3. **Chain**: every link (signature and AIA) is verified with
   `cryptography`, **without** OS trust anchors. A chain made of a single
   non-self-signed certificate is `INVALID`.
4. **Dates**: `EXPIRED` if already expired; `EXPIRING_SOON` if it expires
   in less than 30 days (default threshold `2592000` s).
5. **Revocation**: OCSP (AIA URL) and CRL (CRLDP), leaf first and issuer
   as fallback. The **answer itself** is validated (signed by the issuer,
   consistent CertID/serial, CRL fresh) before trusting its verdict. Any
   valid revocation evidence ⇒ `REVOKED`, even with green dates; lack of
   verifiable evidence ⇒ `INDETERMINATE` (both **fail with distinct
   messages**), and the revocation attribution always points to its real
   source (OCSP or CRL), never to the dates.

Statuses: `VALID | EXPIRED | EXPIRING_SOON | REVOKED | INDETERMINATE |
INVALID | ERROR | SKIPPED` (precedence: SKIPPED > ERROR > INVALID >
REVOKED > INDETERMINATE > EXPIRED > EXPIRING_SOON > VALID).

## Running it

* **Pytest (offline, 17 tests)**: `python3 -m pytest tests/tls -q`
  All fetches (TLS, OCSP/CRL) are injected; no network is used.

* **Robot (live)**:
  ```
  make test auth-<cluster-file> cluster-<definition-file> \
       ROBOT_SUITE=tests/tls/tls-certificates.robot
  ```
  or directly:
  ```
  python3 -m robot -V variables/.env-auth-<cluster-file>.yaml \
       -V variables/.env-cluster-<definition-file>.yaml tests/tls/tls-certificates.robot
  ```

Library keywords (`robot_libs/tls_certificate.py`):

* `Check Tls Certificate` — diagnostic; returns a dict with status and message.
* `Endpoint Certs Are Valid` — the one used by the Robot suite; fails
  unless `VALID`, and *skips* if the URL is undefined, is not HTTPS, or
  `SSL_VERIFY` is false (local `kind` clusters).
