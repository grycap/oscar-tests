*** Settings ***
Documentation       Tests for the OSCAR Manager's API of a deployed OSCAR cluster. Basic endpoint coverage
Library           Process
Library           RequestsLibrary
Resource            ${CURDIR}/../../resources/files.resource

Suite Teardown      Clean Test Artifacts    True    ${DATA_DIR}/service_file.json


*** Variables ***
${SERVICE_NAME}     robot-test-cowsay
${OSCAR_ENDPOINT}   http://localhost
${VO}   oscar
${USER}   oscar
${PASSWORD}   Y2RmMTRj

*** Test Cases ***
OSCAR API Health
    [Documentation]    Check API health
    ${user-pass}=    Get User Password
    VAR    &{HEADERS_LOCALHOST}=    Authorization=Basic ${user-pass}    Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    ${response}=    GET    ${OSCAR_ENDPOINT}/health   headers=&{HEADERS_LOCALHOST}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

OSCAR System Config
    [Documentation]    Get system config
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/config    expected_status=200    headers=&{HEADERS_LOCALHOST}
    Log    ${response.content}
    Should Contain    ${response.content}    "name":"oscar"

OSCAR System Info
    [Documentation]    Get system info
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/info    expected_status=200    headers=&{HEADERS_LOCALHOST}
    Log    ${response.content}
    Should Contain    ${response.content}    "version":

OSCAR Create Service
    [Documentation]    Create a new service
    [Tags]    create
    ${body}=    Get Service File Update     VO      ""
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=201    data=${body}
    ...    headers=${HEADERS_LOCALHOST}
    Sleep    180s
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201


OSCAR List Services
    [Documentation]    Retrieve a list of services
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services    expected_status=200    headers=${HEADERS_LOCALHOST}
    Log    ${response.content}
    Should Contain    ${response.content}    "oscar_service":

OSCAR Read Service
    [Documentation]    Read a service
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=200
    ...    headers=${HEADERS_LOCALHOST}
    Log    ${response.content}
    Should Contain    ${response.content}    "name":"${SERVICE_NAME}"


OSCAR Invoke Asynchronous Service with token
    [Documentation]  Invoke the asynchronous service with token
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/robot-test-cowsay    expected_status=200
    ...                    headers=${HEADERS_LOCALHOST}
    Log    ${response.content}
    ${service_token}=      Evaluate      json.loads($response.content)['token']
    VAR    ${service_token}    ${service_token}
    VAR    &{new_headers}    Authorization=Bearer ${service_token}   Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    ${body}=        Get File    ${INVOKE_FILE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/job/robot-test-cowsay    expected_status=201    data=${body}
    ...                     headers=${new_headers}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR List Jobs
    [Documentation]    List all jobs from a service with their status
    ${list_jobs}=    GET    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}    expected_status=200
    ...    headers=${HEADERS_LOCALHOST}
    ${jobs_dict}=    Evaluate    dict(${list_jobs.content})
    Get Key From Dictionary    ${jobs_dict}
    Log    ${list_jobs.content}     console=yes
    Sleep       60s
    Should Contain    ${JOB_NAME}    ${SERVICE_NAME}-

OSCAR Get Logs
    [Documentation]    Get the logs from a job
    ${get_logs}=    GET    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}/${JOB_NAME}    expected_status=200
    ...    headers=${HEADERS_LOCALHOST}
    Log    ${get_logs.content}
    Should Contain    ${get_logs.content}    Hello

OSCAR Invoke Synchronous Service with token
    [Documentation]  Invoke the synchronous service with token
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/robot-test-cowsay    expected_status=200
    ...                    headers=${HEADERS_LOCALHOST}
    Log    ${response.content}
    ${service_token}=      Evaluate      json.loads($response.content)['token']
    VAR    ${service_token}    ${service_token}
    VAR    &{new_headers}    Authorization=Bearer ${service_token}   Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    ${body}=        Get File    ${INVOKE_FILE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/run/robot-test-cowsay    expected_status=200    data=${body}
    ...                     headers=${new_headers}
    Should Be Equal As Strings    ${response.status_code}    200

OSCAR Delete Job
    [Documentation]    Delete a job from a service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}/${JOB_NAME}    expected_status=204
    ...    headers=${HEADERS_LOCALHOST}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR Delete All Jobs
    [Documentation]    Delete all jobs from a service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS_LOCALHOST}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR Delete Service
    [Documentation]    Delete the created service
    [Tags]    delete
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS_LOCALHOST}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204


*** Keywords ***
Get User Password
    ${AuthorizationHeader}=     Evaluate        base64.b64encode(b"${USER}:${PASSWORD}")
    RETURN      ${AuthorizationHeader}
