*** Settings ***
Documentation       Tests for the OSCAR Manager's API of a deployed OSCAR cluster. Basic endpoint coverage

Resource            ${CURDIR}/../../resources/token.resource
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
    Should Contain    ${response.content}    "numberNodes"

OSCAR System Status with OSCAR USER
    [Documentation]    Get system status with OSCAR USER
    Skip If    '${LOCAL_TESTING}'=='True'    #Skipping in local testing as it gives 500 Internal Server Error
    ${response}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/status
    Log    ${response.content}
    Should Contain    ${response.content}    "numberNodes"

#OSCAR Delete Service If Exists
#    [Documentation]    Delete the OSCAR service ${SERVICE_NAME} if it exists in the cluster
#    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
#    ${status}=    Set Variable    ${response.status_code}
#    Run Keyword If    '${status}'=='200'    Delete Service Now
#    ...    ELSE    Log To Console    Service ${SERVICE_NAME} does not exist, skipping deletion.


OSCAR Create Service
    [Documentation]    Create a new service
    [Tags]    create
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json    
    ${response}=    POST With Defaults  url=${OSCAR_ENDPOINT}/system/services   data=${body}
    Log    ${response.content}
    Sleep   10s
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
    ${response}=    POST With Defaults   url=${OSCAR_ENDPOINT}/run/${SERVICE_NAME}   data=${body}
    Log    ${response.content}
    Should Contain    ${response.content}    Hello

OSCAR Invoke Synchronous Service with token
    [Documentation]  Invoke the synchronous service with service token
    ${response}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    Log    ${response.content}
    ${service_token}=      Evaluate      json.loads($response.content)['token']
    VAR    ${service_token}    ${service_token}
    VAR    &{new_headers}    Authorization=Bearer ${service_token}   Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    ${body}=        Get File    ${INVOKE_FILE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/run/${SERVICE_NAME}    expected_status=200    data=${body}   
    ...                     headers=${new_headers}   verify=${SSL_VERIFY}
    Should Be Equal As Strings    ${response.status_code}    200    

OSCAR Invoke Asynchronous Service
    [Documentation]    Invoke the asynchronous service
    Skip If    '${LOCAL_TESTING}'=='True'    #Skipping in favour of the next one which uses the service token
    ${body}=    Get File    ${INVOKE_FILE}
    ${response}=    POST With Defaults   url=${OSCAR_ENDPOINT}/job/${SERVICE_NAME}     data=${body}
    Sleep    60s
    Should Be Equal As Strings    ${response.status_code}    201

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
    ${get_logs}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}/${JOB_NAME}
    Log    ${get_logs.content}
    Should Contain    ${get_logs.content}    Hello

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
    ${response}=    POST   url=${OSCAR_ENDPOINT}/job/${SERVICE_NAME}      data=${body}
    ...                     headers=${new_headers}    verify=${SSL_VERIFY}
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
