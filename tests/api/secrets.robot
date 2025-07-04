*** Settings ***
Documentation       Tests for the OSCAR Manager's secrets

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

OSCAR Create Service
    [Documentation]    Create a new service with a secret
    [Tags]    create
    # ${body}=    Prepare Service File
    Prepare Service File    robot-secret
    ${body}=    Get File    ${DATA_DIR}/service_file.json

    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR Invoke Asynchronous Service
    [Documentation]    Invoke the asynchronous service
    ${body}=    Get File    ${INVOKE_FILE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/job/${SERVICE_NAME}    expected_status=201    data=${body}
    ...    headers=${HEADERS}
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

    Sleep    5s
    ${response_text}=    Set Variable    ${response_raw.text}
    Should Contain    ${response_text}    robot-secret

OSCAR Delete Job
    [Documentation]    Delete a job from a service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}/${JOB_NAME}    expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR Update Service
    [Documentation]    Update a service
    Prepare Service File    another-robot-secret
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

OSCAR Invoke Asynchronous Service Updated
    [Documentation]    Invoke the asynchronous service
    ${body}=    Get File    ${INVOKE_FILE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/job/${SERVICE_NAME}    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR List Jobs Updated
    [Documentation]    List all jobs from a service with their status
    ${list_jobs}=    GET    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}    expected_status=200
    ...    headers=${HEADERS}
    ${jobs_dict}=    Evaluate    dict(${list_jobs.content})
    Get Key From Dictionary    ${jobs_dict}
    Should Contain    ${JOB_NAME}    ${SERVICE_NAME}-

OSCAR Get Logs Updated
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

    Sleep    5s
    ${response_text}=    Set Variable    ${response_raw.text}
    Should Contain    ${response_text}    another-robot-secret

OSCAR Delete Job Updated
    [Documentation]    Delete a job from a service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}/${JOB_NAME}    expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR Update Service Again
    [Documentation]    Update a service
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

OSCAR Invoke Asynchronous Service Again
    [Documentation]    Invoke the asynchronous service
    ${body}=    Get File    ${INVOKE_FILE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/job/${SERVICE_NAME}    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR List Jobs Again
    [Documentation]    List all jobs from a service with their status
    ${list_jobs}=    GET    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}    expected_status=200
    ...    headers=${HEADERS}
    ${jobs_dict}=    Evaluate    dict(${list_jobs.content})
    Get Key From Dictionary    ${jobs_dict}
    Should Contain    ${JOB_NAME}    ${SERVICE_NAME}-

OSCAR Get Logs Again
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

    Sleep    5s
    ${response_text}=    Set Variable    ${response_raw.text}
    Should Contain    ${response_text}    another-robot-secret

OSCAR Delete Service
    [Documentation]    Delete the created service
    [Tags]    delete
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204


*** Keywords ***
Prepare Service File
    [Arguments]    ${secret_key}=None
    ${service_content}=    Load Original Service File    ${SERVICE_FILE}
    ${service_content}=    Set Service File VO    ${service_content}
    # If the secret key is not provided, use the default script file
    # Otherwise, add the secret echo to the script file
    ${script_to_use}=    Run Keyword If    '${secret_key}'    Add Secret Echo To Script File    ELSE    Get File    ${SCRIPT_FILE}
    ${service_content}=    Set Service File Script    ${service_content}    ${script_to_use}
    ${service_content}=    Set Service File Secret    ${service_content}    ${secret_key}

    Dump Service File To JSON File    ${service_content}    ${DATA_DIR}/service_file.json
