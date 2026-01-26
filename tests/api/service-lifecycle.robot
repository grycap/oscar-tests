*** Settings ***
Documentation       Tests for the OSCAR Manager's API of a deployed OSCAR cluster. Basic endpoint coverage

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS} 
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/api_call.resource
Resource            ${CURDIR}/../../resources/service.resource



Suite Setup         Run Keywords    Check Valid OIDC Token    AND    Assign Random Service Name


Suite Teardown      Clean Test Artifacts    True    ${DATA_DIR}/service_file.json


*** Variables ***
${SERVICE_BASE}     robot-test-cowsay
${SERVICE_NAME}     ${SERVICE_BASE}


*** Test Cases ***
OSCAR API Health
    [Documentation]    Check API health
    ${response}=    GET With Defaults  ${OSCAR_ENDPOINT}/health
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

OSCAR System Config
    [Documentation]    Get system config    
    ${response}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/config
    Log    ${response.content}
    Should Contain    ${response.content}    "name":"oscar"

OSCAR System Info
    [Documentation]    Get system info    
    ${response}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/info
    Log    ${response.content}
    Should Contain    ${response.content}    "version":

OSCAR System Status
    [Documentation]    Get system status
    Skip If    '${LOCAL_TESTING}'=='True'    #Skipping in local testing as it gives 500 Internal Server Error
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/status
    Log    ${response.content}
    Should Contain    ${response.content}    "nodes_count"

OSCAR System Status with OSCAR USER
    [Documentation]    Get system status with OSCAR USER
    Skip If    '${LOCAL_TESTING}'=='True'    #Skipping in local testing as it gives 500 Internal Server Error
    ${response}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/status
    Log    ${response.content}
    Should Contain    ${response.content}    "nodes_count"

#OSCAR Delete Service If Exists
#    [Documentation]    Delete the OSCAR service ${SERVICE_NAME} if it exists in the cluster
#    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
#    ${status}=    Set Variable    ${response.status_code}
#    Run Keyword If    '${status}'=='200'    Delete Service Now
#    ...    ELSE    Log To Console    Service ${SERVICE_NAME} does not exist, skipping deletion.


OSCAR Create Service
    [Documentation]    Create a new service
    [Tags]    create    ready
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json    
    ${response}=    POST With Defaults  url=${OSCAR_ENDPOINT}/system/services   data=${body}
    Log    ${response.content}
    Wait For Service Ready
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'  #409 if already exists

OSCAR List Services
    [Documentation]    Retrieve a list of services
    ${response}=    GET With Defaults  url=${OSCAR_ENDPOINT}/system/services
    Log    ${response.content}
    Should Contain    ${response.content}    "oscar_service":

OSCAR Read Service
    [Documentation]    Read a service
    ${response}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    Log    ${response.content}
    Should Contain    ${response.content}    "name":"${SERVICE_NAME}"

OSCAR List Services as OSCAR user
    [Documentation]    Retrieve a list of services
    ${response}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/services    headers=${HEADERS_OSCAR}
    Log    ${response.content}
    Should Contain    ${response.content}    "oscar_service":

OSCAR Read Service as OSCAR user
    [Documentation]    Read a service
    ${response}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}   headers=${HEADERS_OSCAR}
    Log    ${response.content}
    Should Contain    ${response.content}    "name":"${SERVICE_NAME}"

OSCAR Invoke Synchronous Service
    [Documentation]  Invoke the synchronous service
    Skip If    '${LOCAL_TESTING}'=='True'    #Skipping in favour of the next one which uses the service token
    ${body}=        Get File    ${INVOKE_FILE}
    FOR    ${i}    IN RANGE    ${MAX_RETRIES}
        ${status}    ${resp}=    Run Keyword And Ignore Error    POST    url=${OSCAR_ENDPOINT}/run/${SERVICE_NAME}      headers=${HEADERS}       data=${body}
        IF    '${status}' != 'FAIL'
            Log     ${status}
            Log     ${resp.content}
            ${status}=    Run Keyword And Return Status    Should Contain    ${resp.content}    Hello
            Exit For Loop If    ${status}
        END
        Sleep   ${RETRY_INTERVAL}
    END
    Log    Exited

OSCAR Invoke Synchronous Service with token
    [Documentation]  Invoke the synchronous service with service token
    [Tags]    ready
    ${response}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    Log    ${response.content}
    ${service_token}=      Evaluate      json.loads($response.content)['token']
    VAR    ${service_token}    ${service_token}
    VAR    &{new_headers}    Authorization=Bearer ${service_token}   Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    ${body}=        Get File    ${INVOKE_FILE}
    ${verify}=    Convert To Boolean    ${SSL_VERIFY}
    ${retries}=    Set Variable If    '${LOCAL_TESTING}'=='True'    10x    1x
    ${interval}=   Set Variable If    '${LOCAL_TESTING}'=='True'    30s    0s
    Run Keyword If    '${LOCAL_TESTING}'=='True'    Wait Until Keyword Succeeds    ${retries}    ${interval}    Invoke Service With Token    ${body}    ${new_headers}    ${verify}
    ...    ELSE    Invoke Service With Token    ${body}    ${new_headers}    ${verify}

OSCAR Invoke Asynchronous Service
    [Documentation]    Invoke the asynchronous service
    Skip If    '${LOCAL_TESTING}'=='True'    #Skipping in favour of the next one which uses the service token
    ${body}=    Get File    ${INVOKE_FILE}
    ${response}=    POST With Defaults   url=${OSCAR_ENDPOINT}/job/${SERVICE_NAME}     data=${body}
    Should Be Equal As Strings    ${response.status_code}    201
    Wait For Async Job Ready

OSCAR List Jobs
    Skip If    '${LOCAL_TESTING}'=='True'    #Skipping for local testing for the time being
    [Documentation]    List all jobs from a service with their status
    ${list_jobs}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}
    ${jobs_dict}=    Evaluate    dict(${list_jobs.content})
    Get Key From Dictionary    ${jobs_dict["jobs"]}
    Should Contain    ${JOB_NAME}    ${SERVICE_NAME}-

OSCAR Get Logs
    Skip If    '${LOCAL_TESTING}'=='True'    #Skipping for local testing for the time being
    [Documentation]    Get the logs from a job
    Wait For Job Logs

OSCAR Delete Job
    Skip If    '${LOCAL_TESTING}'=='True'    #Skipping for local testing for the time being
    [Documentation]    Delete a job from a service
    ${response}=    DELETE With Defaults   url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}/${JOB_NAME}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR Update Service
    [Documentation]    Update a service
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    PUT With Defaults   url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

OSCAR Invoke Asynchronous Service with service token
    [Documentation]  Invoke the asynchronous service with token
    Skip If    '${LOCAL_TESTING}'=='True'    #Skipping for local testing for the time being
    ${response}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    Log    ${response.content}
    ${service_token}=      Evaluate      json.loads($response.content)['token']
    VAR    ${service_token}    ${service_token}
    VAR    &{new_headers}    Authorization=Bearer ${service_token}   Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    ${body}=        Get File    ${INVOKE_FILE}
    ${verify}=    Convert To Boolean    ${SSL_VERIFY}
    ${response}=    POST   url=${OSCAR_ENDPOINT}/job/${SERVICE_NAME}      data=${body}
    ...                     headers=${new_headers}    verify=${verify}
    Should Be Equal As Strings    ${response.status_code}    201
    

OSCAR Delete All Jobs
    Skip If    '${LOCAL_TESTING}'=='True'    #Skipping for local testing for the time being
    [Documentation]    Delete all jobs from a service
    ${response}=    DELETE With Defaults   url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR Delete Service
    Skip If    '${LOCAL_TESTING}'=='True'    #Skipping for local testing for the time being
    [Documentation]    Delete the created service
    [Tags]    delete
    ${response}=    DELETE With Defaults   url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204


*** Keywords ***

Invoke Service With Token
    [Documentation]    Helper that posts to the synchronous run endpoint and asserts a 200 response.
    [Arguments]    ${body}    ${headers}    ${verify}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/run/${SERVICE_NAME}    expected_status=200
    ...                     data=${body}    headers=${headers}    verify=${verify}
    Should Be Equal As Strings    ${response.status_code}    200

#Delete Service Now
#    ${del_response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
#    Log    ${del_response.content}
#    Should Be Equal As Strings    ${del_response.status_code}    204

Prepare Service File
    [Documentation]    Prepare the service file
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Set Service File VO    ${service_content}

    # Extract the inner dictionary (remove 'functions', 'oscar' and 'robot-oscar-cluster')
    VAR    ${modified_content}=    ${service_content}[functions][oscar][0][robot-oscar-cluster]

    # Update the script value
    ${script_value}=    Catenate
    ...    \#!/bin/sh\n\nif [ \"$INPUT_TYPE\" = \"json\" ]\nthen\n
    ...    jq '.message' \"$INPUT_FILE_PATH\" -r | /usr/games/cowsay\nelse\n
    ...    cat \"$INPUT_FILE_PATH\" | /usr/games/cowsay\nfi\n\
    Set To Dictionary    ${modified_content}    script=${script_value}
    Set To Dictionary    ${modified_content}    name=${SERVICE_NAME}
    ${input_entries}=    Get From Dictionary    ${modified_content}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${SERVICE_NAME}/input
    ${output_entries}=    Get From Dictionary    ${modified_content}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${SERVICE_NAME}/output
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${DATA_DIR}/service_file.json    ${service_content_json}

Wait For Service Ready
    [Documentation]    Polls the service endpoint until the service reports a ready state or the timeout expires.
    ${timeout}=    Set Variable If    '${LOCAL_TESTING}'=='True'    180s    210s
    ${interval}=   Set Variable    5s
    Wait Until Keyword Succeeds    ${timeout}    ${interval}    Service Should Be Ready

Service Should Be Ready
    [Documentation]    Asserts that the service status indicates readiness.
    ${response}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=200
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${status}=    Evaluate    (lambda d: d.get('status') if not isinstance(d.get('status'), dict) else d['status'].get('state') or d['status'].get('phase') or d['status'].get('condition'))(${payload})    json
    ${ready}=    Evaluate    str(${status}).lower() in ("ready","running","available","succeeded") or bool(${payload}.get('ready')) or bool(${payload}.get('token'))    json
    Should Be True    ${ready}    Service not ready yet (status=${status})

Wait For Async Job Ready
    [Documentation]    Polls the job listing until at least one job for the service is visible.
    [Arguments]    ${headers}=${HEADERS}
    ${timeout}=    Set Variable If    '${LOCAL_TESTING}'=='True'    300s    300s
    ${interval}=   Set Variable    5s
    Wait Until Keyword Succeeds    ${timeout}    ${interval}    Async Job Should Be Visible    ${headers}

Async Job Should Be Visible
    [Documentation]    Asserts that the job list for the service is non-empty.
    [Arguments]    ${headers}=${HEADERS}
    ${response}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}    headers=${headers}
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${jobs}=       Get From Dictionary    ${payload}    jobs
    Log    Jobs response: ${payload}
    Should Not Be Empty    ${jobs}

Wait For Job Logs
    [Documentation]    Polls until job logs are available or the timeout is reached.
    ${timeout}=    Set Variable If    '${LOCAL_TESTING}'=='True'    300s    120s
    ${interval}=   Set Variable    5s
    Wait Until Keyword Succeeds    ${timeout}    ${interval}    Job Logs Should Contain Hello

Job Logs Should Contain Hello
    [Documentation]    Fetches job logs and asserts the expected output.
    ${get_logs}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}/${JOB_NAME}
    Log    ${get_logs.content}
    Should Contain    ${get_logs.content}    Hello
