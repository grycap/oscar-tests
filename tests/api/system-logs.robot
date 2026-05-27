*** Settings ***
Documentation       Tests for the OSCAR API /system/logs endpoint (admin only).

Library             Collections
Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/api_call.resource

Suite Setup         Check Valid OIDC Token


*** Test Cases ***
OSCAR Get System Logs
    [Documentation]    Get system logs with Basic Auth (admin).
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/logs    headers=${HEADERS_OSCAR}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200

OSCAR Get System Logs With Timestamps
    [Documentation]    Get system logs with timestamps parameter.
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/logs?timestamps=true    headers=${HEADERS_OSCAR}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200

OSCAR Get System Logs With Previous
    [Documentation]    Get system logs with previous parameter.
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/logs?previous=true    headers=${HEADERS_OSCAR}    expected_status=ANY
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '400'

OSCAR Get System Logs OIDC Forbidden
    [Documentation]    Get system logs with OIDC token (should fail with 401 or 403).
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/logs    expected_status=ANY
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '401' or '${response.status_code}' == '403'
