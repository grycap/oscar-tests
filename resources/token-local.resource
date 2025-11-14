*** Settings ***
Documentation       Lightweight authentication resource for local OSCAR deployments using Basic auth.

Library             Collections


*** Keywords ***
Check Valid OIDC Token
    [Documentation]    Stub keyword that configures Basic authentication headers for local deployments.
    Ensure Basic Credentials Present
    VAR    &{HEADERS}=    Authorization=Basic ${BASIC_USER}    Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    VAR    &{HEADERS_OSCAR}=    Authorization=Basic ${BASIC_USER}    Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    Set Suite Variable    ${USER}    local-user
    Set Suite Variable    ${USER_SHORT_ID}    local-user

Set Refresh Token
    [Documentation]    Compatibility placeholder for suites that request local refresh tokens.
    Ensure Basic Credentials Present
    VAR    ${REFRESH_TOKEN}=    local-refresh-token
    Set Suite Variable    ${REFRESH_TOKEN}

Get Access Token
    [Documentation]    Compatibility placeholder so Robot suites can request an access token.
    Ensure Basic Credentials Present
    RETURN    local-access-token

Ensure Basic Credentials Present
    [Documentation]    Fails fast if BASIC_USER was not provided in the variable file.
    Run Keyword Unless    '${BASIC_USER}'    Fail    Missing BASIC_USER variable for local authentication.
