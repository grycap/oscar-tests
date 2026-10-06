*** Settings ***
Documentation       Tests the lifecycle and HTTP availability of an exposed OSCAR service.

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/api_call.resource
Resource            ${CURDIR}/../../resources/service.resource

Suite Setup         Run Keywords    Check Valid OIDC Token    AND    Assign Random Service Name
Suite Teardown      Run Keywords    Cleanup Exposed Service Resources    AND    Clean Test Artifacts    ${EXPOSED_SERVICE_JSON}


*** Variables ***
${SERVICE_BASE}            robot-test-nginx
${SERVICE_NAME}            ${SERVICE_BASE}
${EXPOSED_SERVICE_FILE}    ${DATA_DIR}/expose_services/nginx_expose.yaml
${EXPOSED_SCRIPT_FILE}     ${DATA_DIR}/expose_services/nginxscript.sh
${EXPOSED_SERVICE_JSON}    ${DATA_DIR}/nginx_service_file.json


*** Test Cases ***
OSCAR Create Exposed Service
    [Documentation]    Create an exposed nginx service.
    [Tags]    create
    Prepare Exposed Service File
    ${body}=    Get File    ${EXPOSED_SERVICE_JSON}
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR Access Exposed Service
    [Documentation]    Wait until the exposed service is available through its DNS name.
    Wait Until Keyword Succeeds
    ...    ${MAX_RETRIES}x
    ...    ${RETRY_INTERVAL}
    ...    Exposed Service Should Be Available

OSCAR Delete Exposed Service
    [Documentation]    Delete the exposed service.
    [Tags]    delete
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204


*** Keywords ***
Prepare Exposed Service File
    [Documentation]    Build the exposed service JSON using a unique service name and the configured VO.
    ${service_content}=    Get File    ${EXPOSED_SERVICE_FILE}
    ${service_content}=    Set Service File VO    ${service_content}
    ${service}=    Set Variable    ${service_content}[functions][oscar][0][oscar-cluster]
    Set To Dictionary    ${service}    name=${SERVICE_NAME}
    ${script_content}=    Get File    ${EXPOSED_SCRIPT_FILE}
    ${service_content}=    Set Service File Script    ${service_content}    ${script_content}
    Dump Service File To JSON File    ${service_content}    ${EXPOSED_SERVICE_JSON}

Exposed Service Should Be Available
    [Documentation]    Check that the exposed service returns the expected nginx page.
    ${url}=    Build Exposed Service URL    ${SERVICE_NAME}
    ${response}=    GET With Defaults    url=${url}
    Log    ${response.content}
    Should Contain    ${response.content}    Welcome to nginx!

Cleanup Exposed Service Resources
    [Documentation]    Best-effort cleanup of the service created by this suite.
    Run Keyword And Ignore Error
    ...    DELETE With Defaults
    ...    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    ...    expected_status=ANY
