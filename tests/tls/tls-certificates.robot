*** Settings ***
Documentation     Read-only check that the TLS certificates presented by the
...                OSCAR endpoints are sound: not expired, not expiring in the next
...                30 days, and not revoked (any valid OCSP/CRL evidence).
...                Creates no cluster resources; no authentication token needed.
...                See robot_libs/tls_certificate.py (issue #587).
Library           ${CURDIR}/../../robot_libs/tls_certificate.py
Resource          ${CURDIR}/../../resources/files.resource


*** Test Cases ***

OSCAR Endpoint TLS Certificate Is Valid
    [Documentation]    The endpoint ${OSCAR_ENDPOINT} must present a valid,
    ...                non-expired, non-revoked TLS certificate for its own hostname.
    Certificates Are Valid    ${OSCAR_ENDPOINT}    ${SSL_VERIFY}

OSCAR Dashboard TLS Certificate Is Valid
    [Documentation]    The dashboard ${OSCAR_DASHBOARD} must present a valid,
    ...                non-expired, non-revoked TLS certificate for its own hostname.
    Certificates Are Valid    ${OSCAR_DASHBOARD}    ${SSL_VERIFY}


*** Keywords ***

Certificates Are Valid
    [Arguments]    ${URL}    ${SslVerify}
    [Documentation]    Fails unless the endpoint certificate is VALID; skips
    ...                when the URL is undefined, not HTTPS, or ${SslVerify} is
    ...                false (local kind setups without proper TLS).
    Endpoint Certs Are Valid    ${URL}    ${SslVerify}
