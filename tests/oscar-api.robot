*** Comments *** 

Tests for the OSCAR Manager's API of a deployed OSCAR cluster.


*** Settings ***

Library    RequestsLibrary
Resource    ../resources/resources.robot


*** Keywords ***

Get Key From Dictionary
    [Documentation]  Get the key from a dictionary
    [Arguments]    ${dict}
    ${keys}=    Get Dictionary Keys    ${dict}
    Set Suite Variable    ${job_name}    ${keys}[0]
    RETURN    ${job_name}


*** Test Cases ***
    
Check Valid OIDC Token
    ${token}=    Get Access Token
    Check JWT Expiration    ${token}

OSCAR API health
    [Documentation]    Check API health
    ${response}=    GET  ${OSCAR_ENDPOINT}/health  expected_status=200
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

OSCAR system config
    [Documentation]  Get system config
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/config   expected_status=200    headers=${headers}
    Log    ${response.content}
    Should Contain    ${response.content}    "name":"oscar"

OSCAR system info
    [Documentation]  Get system info
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/info   expected_status=200    headers=${headers}
    Log    ${response.content}
    Should Contain    ${response.content}    "version":

OSCAR create service
    [Documentation]  Create a new service
    ${body}=        Get File    ./data/00-cowsay.json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=201    data=${body}    headers=${headers}
    Sleep    30s    # Maybe needs more time to create the service
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR list services 
    [Documentation]  Retrieve a list of services 
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services    expected_status=200    headers=${headers}
    Log    ${response.content}
    Should Contain    ${response.content}    "oscar_service":"robot-test-cowsay"

OSCAR read service
    [Documentation]  Read a service
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/robot-test-cowsay    expected_status=200    headers=${headers}
    Log    ${response.content}
    Should Contain    ${response.content}    "name":"robot-test-cowsay"

OSCAR invoke synchronous service
    [Documentation]  Invoke the synchronous service
    ${body}=        Get File    ./data/00-cowsay-invoke-body.json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/run/robot-test-cowsay    expected_status=200    data=${body}    headers=${headers}
    Log    ${response.content}
    Should Contain    ${response.content}    Hello

OSCAR update service
    [Documentation]  Update a service
    ${body}=        Get File    ./data/00-cowsay.json
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    expected_status=204    data=${body}    headers=${headers}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR invoke asynchronous service
    [Documentation]  Invoke the asynchronous service
    ${body}=        Get File    ./data/00-cowsay-invoke-body.json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/job/robot-test-cowsay    expected_status=201    data=${body}    headers=${headers}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR list jobs
    [Documentation]  List all jobs from a service with their status
    ${list_jobs}=        GET    url=${OSCAR_ENDPOINT}/system/logs/robot-test-cowsay    expected_status=200        headers=${headers}
    Sleep    15s
    ${jobs_dict}=    Evaluate    dict(${list_jobs.content})
    ${job_name}=    Get Key From Dictionary    ${jobs_dict}
    Should Contain    ${job_name}    robot-test-cowsay-

OSCAR get logs
    [Documentation]  Get the logs from a job
    ${get_logs}=        GET    url=${OSCAR_ENDPOINT}/system/logs/robot-test-cowsay/${job_name}   expected_status=200    headers=${headers}
    Log    ${get_logs.content}
    Should Contain    ${get_logs.content}    Hello

OSCAR delete job
    [Documentation]  Delete a job from a service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/logs/robot-test-cowsay/${job_name}    expected_status=204    headers=${headers}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR delete jobs
    [Documentation]  Delete jobs from a service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/logs/robot-test-cowsay    expected_status=204    headers=${headers}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR delete service
    [Documentation]  Delete the created service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/robot-test-cowsay   expected_status=204    headers=${headers}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Remove files from tests
    [Documentation]    Remove junk files created during the tests
    Remove files from tests and verify    True
