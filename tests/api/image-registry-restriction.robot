*** Settings ***
Documentation       Tests for Docker image restriction configuration in the OSCAR Manager API.
...    Covers strict validation of PUT /system/config allowed_image_repositories entries
...    (grycap/oscar PR #726, issue #575) and enforcement at service creation time.

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/api_call.resource
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/service.resource

Suite Setup         Prepare Image Restriction Test
Suite Teardown      Run Keywords    Cleanup Image Restriction Resources    AND    Clean Test Artifacts    ${ALLOWED_SERVICE_FILE}    ${DENIED_SERVICE_FILE}

*** Variables ***
${SERVICE_BASE}         robot-test-allowed
${DENIED_SERVICE_BASE}  robot-test-denied
${ALLOWED_IMAGE}        ghcr.io/grycap/cowsay
${DENIED_IMAGE}         alpine
${ALLOWED_SERVICE_FILE}    image-restriction-allowed-service.json
${DENIED_SERVICE_FILE}     image-restriction-denied-service.json


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

OSCAR System Config Update With Invalid Entries Returns 400
    [Documentation]    PUT /system/config with entries that are not fully qualified
    ...    registry/repository references must be rejected with 400 and an error message
    ...    per invalid entry (grycap/oscar PR #726).
    ${payload}=    Set Variable    {"allowed_image_repositories":["ghcr.io/grycap","test/test","test"]}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/config    data=${payload}    expected_status=400    verify=${SSL_VERIFY}    headers=${HEADERS_OSCAR}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    400
    Should Contain    ${response.text}    invalid allowed image repository "test/test"
    Should Contain    ${response.text}    invalid allowed image repository "test"

OSCAR System Config Unchanged After Rejected Update
    [Documentation]    GET /system/config after the rejected PUT and verify that
    ...    allowed_image_repositories still holds the value captured at the start of the suite
    ...    (the configuration is only updated when the PUT is accepted).
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/config    expected_status=200    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    ${config}=    Evaluate    json.loads($response.content)
    ${allowed_repositories}=    Get From Dictionary    ${config}    allowed_image_repositories
    Should Be Equal    ${allowed_repositories}    ${ORIGINAL_ALLOWED_REPOSITORIES}

OSCAR System Config Update Using Admin Returns 200
    [Documentation]    PUT /system/config using admin user oscar and expect 200
    VAR    &{HEADERS}=    Authorization=Basic ${BASIC_USER}    Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    ${payload}=    Set Variable    {"allowed_image_repositories":["ghcr.io/grycap"]}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/config    data=${payload}    expected_status=200    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200

OSCAR System Config Update With Empty List Returns 200
    [Documentation]    PUT /system/config with an empty allowed_image_repositories list returns 200
    ...    and clears the restriction, so the subsequent GET shows an empty list.
    ${payload}=    Set Variable    {"allowed_image_repositories":[]}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/config    data=${payload}    expected_status=200    verify=${SSL_VERIFY}    headers=${HEADERS_OSCAR}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200

    ${get_response}=    GET    url=${OSCAR_ENDPOINT}/system/config    expected_status=200    verify=${SSL_VERIFY}    headers=${HEADERS_OSCAR}
    Log    ${get_response.content}
    ${config}=    Evaluate    json.loads($get_response.content)
    ${allowed_repositories}=    Get From Dictionary    ${config}    allowed_image_repositories
    @{empty_list}=    Create List
    Should Be Equal    ${allowed_repositories}    ${empty_list}

OSCAR Service Creation Enforces Allowed Image Repositories
    [Documentation]    With an active allowlist, creating a service whose image
    ...    is not allowed must be rejected (the check runs before any cluster resource is
    ...    created), while creating a service with an allowed image (the cowsay template)
    ...    must succeed (grycap/oscar PR #726).
    ${payload}=    Set Variable    {"allowed_image_repositories":["ghcr.io/grycap"]}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/config    data=${payload}    expected_status=200    verify=${SSL_VERIFY}    headers=${HEADERS_OSCAR}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200

    ${denied_body}=    Get File    ${DENIED_SERVICE_FILE}
    ${denied_response}=    POST    url=${OSCAR_ENDPOINT}/system/services    data=${denied_body}    expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS_OSCAR}
    Log    ${denied_response.content}
    Should Not Be Equal As Strings    ${denied_response.status_code}    201    Service with a restricted image must not be created
    Should Contain    ${denied_response.text}    is not allowed

    ${body}=    Get File    ${ALLOWED_SERVICE_FILE}
    ${allowed_response}=    POST    url=${OSCAR_ENDPOINT}/system/services    data=${body}    expected_status=201    verify=${SSL_VERIFY}    headers=${HEADERS_OSCAR}
    Log    ${allowed_response.content}
    Should Be Equal As Strings    ${allowed_response.status_code}    201


*** Keywords ***
Prepare Image Restriction Test
    [Documentation]    Gets the authentication tickets, derives the random service names and
    ...    prepares the two service files (one with an allowed image, one with a restricted one).
    Check Valid OIDC Token
    Assign Random Service Name
    ${denied_name}=    Generate Random Service Name    ${DENIED_SERVICE_BASE}
    Set Suite Variable    ${DENIED_SERVICE_NAME}    ${denied_name}
    Prepare Image Restriction Service File    ${ALLOWED_IMAGE}    ${SERVICE_NAME}    ${ALLOWED_SERVICE_FILE}
    Prepare Image Restriction Service File    ${DENIED_IMAGE}    ${DENIED_SERVICE_NAME}    ${DENIED_SERVICE_FILE}

Prepare Image Restriction Service File
    [Documentation]    Builds a service file from the cowsay template with the given image,
    ...    service name and bucket paths, and saves it as JSON.
    [Arguments]    ${image}    ${service_name}    ${saved_file}
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Set Service File VO    ${service_content}
    ${script_content}=    Get File    ${DATA_DIR}/00-cowsay-script.sh
    ${service_content}=    Set Service File Script    ${service_content}    ${script_content}
    ${modified_content}=    Set Variable    ${service_content}[functions][oscar][0][robot-oscar-cluster]
    Set To Dictionary    ${modified_content}    image=${image}
    Set To Dictionary    ${modified_content}    name=${service_name}
    ${first_input}=    Get From List    ${modified_content}[input]    0
    Set To Dictionary    ${first_input}    path=${service_name}/input
    ${first_output}=    Get From List    ${modified_content}[output]    0
    Set To Dictionary    ${first_output}    path=${service_name}/output
    Dump Service File To JSON File    ${service_content}    ${saved_file}

Cleanup Image Restriction Resources
    [Documentation]    Best-effort cleanup: removes any service this suite could have created and
    ...    restores the original allowed_image_repositories configuration.
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=ANY    headers=${HEADERS_OSCAR}
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${DENIED_SERVICE_NAME}    expected_status=ANY    headers=${HEADERS_OSCAR}
    ${original}=    Get Variable Value    ${ORIGINAL_ALLOWED_REPOSITORIES}    ${None}
    Return From Keyword If    $original is None
    ${payload}=    Evaluate    json.dumps({"allowed_image_repositories": $original})    json
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/config    data=${payload}    expected_status=200    verify=${SSL_VERIFY}    headers=${HEADERS_OSCAR}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
