*** Settings ***
Documentation       Tests for the OSCAR Manager's API of a deployed OSCAR cluster. Basic endpoint coverage

Resource            ${CURDIR}/../resources/files.resource
Resource            ${CURDIR}/../resources/token.resource

Suite Setup         Check Valid OIDC Token
Suite Teardown      Clean Test Artifacts    True    ${DATA_DIR}/nginx_service_file.json


*** Variables ***
${SERVICE_FILE}     ${DATA_DIR}/expose_services/nginx_expose.yaml
${SCRIPT_FILE}      ${DATA_DIR}/expose_services/nginxscript.sh
${SERVICE_NAME}     robot-test-nginx


*** Test Cases ***
OSCAR Create Expose Service
    [Documentation]    Create a new service
    [Tags]    create
    # ${body}=    Prepare Service File
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/nginx_service_file.json

    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR Expose Service Get Service
    [Documentation]    Wait until the exposed service becomes available and check it works
    Wait Until Keyword Succeeds
    ...    ${MAX_RETRIES}x
    ...    ${RETRY_INTERVAL}
    ...    Check Exposed Service

OSCAR Expose Service Delete Service
    [Documentation]    Delete the created service
    [Tags]    delete
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204


*** Keywords ***
Prepare Service File
    [Documentation]    Prepare the service file for service creation
    ${service_content}=    Load Original Service File    ${DATA_DIR}/expose_services/nginx_expose.yaml
    ${service_content}=    Set Service File VO    ${service_content}
    ${script_content}=    Get File    ${SCRIPT_FILE}
    ${service_content}=    Set Service File Script    ${service_content}    ${script_content}
    Dump Service File To JSON File    ${service_content}    ${DATA_DIR}/nginx_service_file.json
    # RETURN    ${service_content}

Check Exposed Service
    [Documentation]    Check if the exposed service is available
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}/exposed    expected_status=200
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    Welcome to nginx!
