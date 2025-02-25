*** Settings ***
Documentation     Tests for the OSCAR Manager's API of a deployed OSCAR cluster.

Library           RequestsLibrary
Resource          ${CURDIR}/../resources/resources.resource

Suite Teardown    Remove Files From Tests And Verify    True    ${DATA_DIR}/service_file.json


*** Test Cases ***
Check Valid OIDC Token
    [Documentation]    Get the access token
    ${token}=    Get Access Token
    Check JWT Expiration    ${token}

OSCAR API Health
    [Documentation]    Check API health
    ${response}=    GET  ${OSCAR_ENDPOINT}/health  expected_status=200
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

OSCAR System Config
    [Documentation]  Get system config
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/config   expected_status=200    headers=&{HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    "name":"oscar"

OSCAR System Info
    [Documentation]  Get system info
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/info   expected_status=200    headers=&{HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    "version":

OSCAR Create Service
    [Documentation]  Create a new service
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json

    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=201    data=${body}
    ...                     headers=${HEADERS}
    Sleep    30s    # May need more time to create the service
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR List Services
    [Documentation]  Retrieve a list of services
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services    expected_status=200    headers=${HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    "oscar_service":

OSCAR Read Service
    [Documentation]  Read a service
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/robot-test-cowsay    expected_status=200
    ...                    headers=${HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    "name":"robot-test-cowsay"

OSCAR Invoke Synchronous Service
    [Documentation]  Invoke the synchronous service
    ${body}=        Get File    ${DATA_DIR}/${INVOKE_FILE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/run/robot-test-cowsay    expected_status=200    data=${body}
    ...                     headers=${HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    Hello

OSCAR Update Service
    [Documentation]  Update a service
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

OSCAR Invoke Asynchronous Service
    [Documentation]  Invoke the asynchronous service
    ${body}=        Get File    ${DATA_DIR}/${INVOKE_FILE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/job/robot-test-cowsay    expected_status=201    data=${body}
    ...                     headers=${HEADERS}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR List Jobs
    [Documentation]  List all jobs from a service with their status
    ${list_jobs}=        GET    url=${OSCAR_ENDPOINT}/system/logs/robot-test-cowsay    expected_status=200
    ...                         headers=${HEADERS}
    Sleep    15s
    ${jobs_dict}=    Evaluate    dict(${list_jobs.content})
    Get Key From Dictionary    ${jobs_dict}
    Should Contain    ${JOB_NAME}    robot-test-cowsay-

OSCAR Get Logs
    [Documentation]  Get the logs from a job
    ${get_logs}=        GET    url=${OSCAR_ENDPOINT}/system/logs/robot-test-cowsay/${JOB_NAME}   expected_status=200
    ...                        headers=${HEADERS}
    Log    ${get_logs.content}
    Should Contain    ${get_logs.content}    Hello

OSCAR Delete Job
    [Documentation]  Delete a job from a service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/logs/robot-test-cowsay/${JOB_NAME}    expected_status=204
    ...                       headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR Delete All Jobs
    [Documentation]  Delete all jobs from a service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/logs/robot-test-cowsay    expected_status=204
    ...                       headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR Delete Service
    [Documentation]  Delete the created service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/robot-test-cowsay   expected_status=204
    ...                       headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204


*** Keywords ***
Get Key From Dictionary
    [Documentation]  Get the key from a dictionary
    [Arguments]    ${dict}
    ${keys}=    Get Dictionary Keys    ${dict}
    IF    not ${keys}    Fail    The dictionary is empty. Cannot extract job.
    ${JOB_NAME}=    Get From List    ${keys}    0
    VAR    ${JOB_NAME}    ${keys}[0]    scope=SUITE
    RETURN    ${JOB_NAME}

Prepare Service File
    [Documentation]    Prepare the service file
    ${service_content}=    Modify Service File

    # Extract the inner dictionary (remove 'functions', 'oscar' and 'robot-oscar-cluster')
    ${modified_content}=    Set Variable    ${service_content}[functions][oscar][0][robot-oscar-cluster]

    # Update the script value
    ${script_value}=    Catenate
    ...    \#!/bin/sh\n\nif [ \"$INPUT_TYPE\" = \"json\" ]\nthen\n
    ...    jq '.message' \"$INPUT_FILE_PATH\" -r | /usr/games/cowsay\nelse\n
    ...    cat \"$INPUT_FILE_PATH\" | /usr/games/cowsay\nfi\n\
    Set To Dictionary    ${modified_content}    script=${script_value}
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${DATA_DIR}/service_file.json    ${service_content_json}
