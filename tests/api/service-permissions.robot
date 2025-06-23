*** Settings ***
Documentation       Tests for the OSCAR Manager's API of a deployed OSCAR cluster. Different access control scenarios.

Resource            ${CURDIR}/../../resources/resources.resource
Resource            ${CURDIR}/../../resources/token.resource

Suite Teardown      Clean Test Artifacts    True    ${DATA_DIR}/private_service_file.json


*** Variables ***
${SERVICE_NAME}     robot-test-cowsay


*** Test Cases ***
Check Valid OIDC Token
    [Documentation]    Get the access token
    [Tags]    create    delete
    ${token}=    Get Access Token
    Check JWT Expiration    ${token}

OSCAR Create Private Service
    [Documentation]    Create a new private service
    [Tags]    create
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/private_service_file.json

    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    ...    headers=${HEADERS}
    Sleep    120s
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR Delete Service
    [Documentation]    Delete the created service
    [Tags]    delete
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204


*** Keywords ***
Prepare Service File
    [Documentation]    Prepare the service file for service creation
    ${service_content}=    Load Original Service File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Set VO    ${service_content}
    ${service_content}=    Set Isolation Level    ${service_content}
    ${service_content}=    Set Service Script    ${service_content}
    Dump Service To JSON File    ${service_content}    ${DATA_DIR}/private_service_file.json
