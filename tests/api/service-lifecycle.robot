*** Settings ***
Documentation       Tests for the OSCAR Manager's API of a deployed OSCAR cluster. Basic endpoint coverage

Resource            ${CURDIR}/../../resources/resources.resource
Resource            ${CURDIR}/../../resources/token.resource

Suite Teardown      Clean Test Artifacts    True    ${DATA_DIR}/service_file.json


*** Variables ***
${SERVICE_NAME}     robot-test-cowsay


*** Test Cases ***
Check Valid OIDC Token
    [Documentation]    Get the access token
    [Tags]    create    delete
    ${token}=    Get Access Token
    Check JWT Expiration    ${token}

OSCAR API Health
    [Documentation]    Check API health
    ${response}=    GET    ${OSCAR_ENDPOINT}/health    expected_status=200
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

OSCAR System Config
    [Documentation]    Get system config
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/config    expected_status=200    headers=&{HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    "name":"oscar"

OSCAR System Info
    [Documentation]    Get system info
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/info    expected_status=200    headers=&{HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    "version":

OSCAR Create Service
    [Documentation]    Create a new service
    [Tags]    create
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json

    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Sleep    120s
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR List Services
    [Documentation]    Retrieve a list of services
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services    expected_status=200    headers=${HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    "oscar_service":

OSCAR Read Service
    [Documentation]    Read a service
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=200
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    "name":"${SERVICE_NAME}"

OSCAR Invoke Synchronous Service
    [Documentation]    Invoke the synchronous service
    ${body}=    Get File    ${INVOKE_FILE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/run/${SERVICE_NAME}    expected_status=200    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    Hello

OSCAR Update Service
    [Documentation]    Update a service
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

OSCAR Invoke Asynchronous Service
    [Documentation]    Invoke the asynchronous service
    ${body}=    Get File    ${INVOKE_FILE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/job/${SERVICE_NAME}    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Sleep    120s
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR List Jobs
    [Documentation]    List all jobs from a service with their status
    ${list_jobs}=    GET    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}    expected_status=200
    ...    headers=${HEADERS}
    ${jobs_dict}=    Evaluate    dict(${list_jobs.content})
    Get Key From Dictionary    ${jobs_dict}
    Should Contain    ${JOB_NAME}    ${SERVICE_NAME}-

OSCAR Get Logs
    [Documentation]    Get the logs from a job
    ${get_logs}=    GET    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}/${JOB_NAME}    expected_status=200
    ...    headers=${HEADERS}
    Log    ${get_logs.content}
    Should Contain    ${get_logs.content}    Hello

OSCAR Delete Job
    [Documentation]    Delete a job from a service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}/${JOB_NAME}    expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR Delete All Jobs
    [Documentation]    Delete all jobs from a service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

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
    ${service_content}=    Set Service Script    ${service_content}
    Dump Service To JSON File    ${service_content}    ${DATA_DIR}/service_file.json
