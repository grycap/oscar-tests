*** Settings ***
Documentation       Tests for Docker image restriction configuration in the OSCAR Manager API.

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/api_call.resource

Suite Setup         Check Valid OIDC Token
Suite Teardown      Cleanup System Config Resources

*** Test Cases ***
OSCAR System Config Shows Allowed Image Repositories
    [Documentation]    GET /system/config and verify that allowed_image_repositories is a list of strings
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/config    expected_status=200    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200

    ${config}=    Evaluate    json.loads($response.content)
    ${allowed_repositories}=    Get From Dictionary    ${config}    allowed_image_repositories
    ${is_list}=    Evaluate    isinstance($allowed_repositories, list)
    ${all_are_strings}=    Evaluate    all(isinstance(item, str) for item in $allowed_repositories)
    Should Be True    ${is_list}
    Should Be True    ${all_are_strings}
    VAR    ${ORIGINAL_ALLOWED_REPOSITORIES}    ${allowed_repositories}    scope=SUITE

OSCAR System Config Update Using OIDC User Returns 401
    [Documentation]    PUT /system/config using oidc user and expect 401
    ${payload}=    Set Variable    {"allowed_image_repositories":["docker.io"]}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/config    data=${payload}    expected_status=401    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    401

OSCAR System Config Update Using Admin Returns 200
    [Documentation]    PUT /system/config using admin user oscar and expect 200
    VAR    &{HEADERS}=    Authorization=Basic ${BASIC_USER}    Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    ${payload}=    Set Variable    {"allowed_image_repositories":["ghcr.io/grycap"]}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/config    data=${payload}    expected_status=200    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200

*** Keywords ***
Cleanup System Config Resources
    [Documentation]    PUT /system/config to restore the original allowed_image_repositories configuration
    VAR    &{HEADERS}=    Authorization=Basic ${BASIC_USER}    Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    ${original}=    Get Variable Value    ${ORIGINAL_ALLOWED_REPOSITORIES}    ${None}
    Return From Keyword If    $original is None
    ${payload}=    Evaluate    json.dumps({"allowed_image_repositories": $original})    json
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/config    data=${payload}    expected_status=200    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
