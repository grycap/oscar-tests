*** Settings ***
Documentation       Tests for the OSCAR Manager's API of a deployed OSCAR cluster. Basic endpoint coverage

Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/token.resource

Suite Setup         Check Valid OIDC Token
Suite Teardown      Clean Test Artifacts    True    ${DATA_DIR}/service_file.json


*** Test Cases ***
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

OSCAR Create Public Service
    [Documentation]    Create a new service
    [Tags]    create
    # ${body}=    Prepare Service File
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json

    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    # Sleep    120s
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

# OSCAR Invoke Synchronous Service
#    [Documentation]    Invoke the synchronous service
#    ${body}=    Get File    ${INVOKE_FILE}
#    ${response}=    POST    url=${OSCAR_ENDPOINT}/run/${SERVICE_NAME}    expected_status=200    data=${body}
#    ...    headers=${HEADERS}
#    Log    ${response.content}
#    Should Contain    ${response.content}    Hello

OSCAR Invoke Synchronous Service
    [Documentation]    Invoke the synchronous service
    ${body}=    Get File    ${INVOKE_FILE}

    FOR    ${_}    IN RANGE    ${MAX_RETRIES}
        ${result}=    Run Keyword And Ignore Error    POST    url=${OSCAR_ENDPOINT}/run/${SERVICE_NAME}
        ...    data=${body}    headers=${HEADERS}
        VAR    ${rc}=    ${result[0]}
        VAR    ${response_raw}=    ${result[1]}
        ${status_code}=    Set Variable If    '${rc}' == 'PASS'    ${response_raw.status_code}

        IF    '${status_code}' == '200'    BREAK

        Log    Service not ready yet. Status: ${response_raw}. Retrying in ${RETRY_INTERVAL}...
        Sleep    ${RETRY_INTERVAL}
    END
    Should Be Equal As Strings    ${status_code}    200    msg=Service was not ready after ${MAX_RETRIES} attempts

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
    # Sleep    120s
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR List Jobs
    [Documentation]    List all jobs from a service with their status
    ${list_jobs}=    GET    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}    expected_status=200
    ...    headers=${HEADERS}
    ${jobs_dict}=    Evaluate    dict(${list_jobs.content})
    Get Key From Dictionary    ${jobs_dict}
    Should Contain    ${JOB_NAME}    ${SERVICE_NAME}-

# OSCAR Get Logs
#    [Documentation]    Get the logs from a job
#    ${get_logs}=    GET    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}/${JOB_NAME}    expected_status=200
#    ...    headers=${HEADERS}
#    Log    ${get_logs.content}
#    Should Contain    ${get_logs.content}    Hello

OSCAR Get Logs
    [Documentation]    Get the logs from a job
    FOR    ${_}    IN RANGE    ${MAX_RETRIES}
        ${result}=    Run Keyword And Ignore Error    GET
        ...    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}/${JOB_NAME}    headers=${HEADERS}
        VAR    ${rc}=    ${result[0]}
        VAR    ${response_raw}=    ${result[1]}
        ${status_code}=    Set Variable If    '${rc}' == 'PASS'    ${response_raw.status_code}

        IF    '${status_code}' == '200'    BREAK

        Log    Service not ready yet. Status: ${response_raw}. Retrying in ${RETRY_INTERVAL}...
        Sleep    ${RETRY_INTERVAL}
    END
    Should Be Equal As Strings    ${status_code}    200    msg=Service was not ready after ${MAX_RETRIES} attempts

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

OSCAR Delete Public Service
    [Documentation]    Delete the created service
    [Tags]    delete
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204


*** Keywords ***
Prepare Service File
    [Documentation]    Prepare the service file for service creation
    ${service_content}=    Load Original Service File    ${SERVICE_FILE}
    ${service_content}=    Set Service File VO    ${service_content}
    ${service_content}=    Set Service File Script    ${service_content}
    Dump Service File To JSON File    ${service_content}    ${DATA_DIR}/service_file.json
    # RETURN    ${service_content}
