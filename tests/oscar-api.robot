*** Settings ***
Documentation    Tests for the OSCAR Manager's API of a deployed OSCAR cluster.

Library          RequestsLibrary
Resource         ../resources/resources.resource


*** Test Cases ***
Check Valid OIDC Token
    ${token}=    Get Access Token
    Check JWT Expiration    ${token}

OSCAR API Health
    [Documentation]    Check API health
    ${response}=    GET  ${OSCAR_ENDPOINT}/health  expected_status=200
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

OSCAR System Config
    [Documentation]  Get system config
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/config   expected_status=200    headers=${HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    "name":"oscar"

OSCAR System Info
    [Documentation]  Get system info
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/info   expected_status=200    headers=${HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    "version":

OSCAR Create Service
    [Documentation]  Create a new service
    ${body}=        Get File    ./data/00-cowsay.json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=201    data=${body}    headers=${HEADERS}
    Sleep    30s    # May need more time to create the service
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR List Services 
    [Documentation]  Retrieve a list of services 
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services    expected_status=200    headers=${HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    "oscar_service":"robot-test-cowsay"

OSCAR Read Service
    [Documentation]  Read a service
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/robot-test-cowsay    expected_status=200    headers=${HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    "name":"robot-test-cowsay"

OSCAR Invoke Synchronous Service
    [Documentation]  Invoke the synchronous service
    ${body}=        Get File    ./data/00-cowsay-invoke-body.json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/run/robot-test-cowsay    expected_status=200    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    Hello

OSCAR Update Service
    [Documentation]  Update a service
    ${body}=        Get File    ./data/00-cowsay.json
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    expected_status=204    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR Invoke Asynchronous Service
    [Documentation]  Invoke the asynchronous service
    ${body}=        Get File    ./data/00-cowsay-invoke-body.json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/job/robot-test-cowsay    expected_status=201    data=${body}    headers=${HEADERS}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR List Jobs
    [Documentation]  List all jobs from a service with their status
    ${list_jobs}=        GET    url=${OSCAR_ENDPOINT}/system/logs/robot-test-cowsay    expected_status=200        headers=${HEADERS}
    Sleep    15s
    ${jobs_dict}=    Evaluate    dict(${list_jobs.content})
    Get Key From Dictionary    ${jobs_dict}
    Should Contain    ${JOB_NAME}    robot-test-cowsay-

OSCAR Get Logs
    [Documentation]  Get the logs from a job
    ${get_logs}=        GET    url=${OSCAR_ENDPOINT}/system/logs/robot-test-cowsay/${JOB_NAME}   expected_status=200    headers=${HEADERS}
    Log    ${get_logs.content}
    Should Contain    ${get_logs.content}    Hello

OSCAR Delete Job
    [Documentation]  Delete a job from a service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/logs/robot-test-cowsay/${JOB_NAME}    expected_status=204    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR Delete All Jobs
    [Documentation]  Delete jobs from a service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/logs/robot-test-cowsay    expected_status=204    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR Delete Service
    [Documentation]  Delete the created service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/robot-test-cowsay   expected_status=204    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Remove Files From Tests
    [Documentation]    Remove junk files created during the tests
    Remove Files From Tests And Verify    True


*** Keywords ***
Get Key From Dictionary
    [Documentation]  Get the key from a dictionary
    [Arguments]    ${dict}
    ${keys}=    Get Dictionary Keys    ${dict}
    Set Suite Variable    ${JOB_NAME}    ${keys}[0]
    RETURN    ${JOB_NAME}