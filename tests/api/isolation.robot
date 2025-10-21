*** Settings ***
Documentation     Tests for the OSCAR Manager's API of a deployed OSCAR cluster.
Library           Process
Library           RequestsLibrary
Resource          ${CURDIR}/../../resources/token.resource
Resource          ${CURDIR}/../../resources/files.resource

Suite Setup       Checks Valids OIDC Token
Suite Teardown    Clean Test Artifacts    True    ${DATA_DIR}/service_file.json


*** Variables ***
${service_name}     robot-test-cowsay
${bucket_name}      robot-test-cowsay

*** Test Cases ***

OSCAR API Health
    [Documentation]    Check API health
    ${response}=    GET  ${OSCAR_ENDPOINT}/health  expected_status=200
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

OSCAR Service isolation_level SERVICE Create
    [Documentation]  Create a new service
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json

    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=201    data=${body}
    ...                     headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201
    Sleep    20s

Verify Service isolation_level SERVICE Creation
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${bucket_name}","visibility":"private"
    ${output} = 	Convert To String 	${response.content}
    Should Not Match Regexp    ${output}    "bucket_name":"${bucket_name}-${FIRST_USER_ID} ","visibility":"private"
    ${response}=    Verify Second Bucket
    ${output} = 	Convert To String 	${response.content}
    Should Not Match Regexp    ${output}    "bucket_name":"${bucket_name}-${SECOND_USER_ID}","visibility":"private"

OSCAR Service isolation_level SERVICE -> USER Update
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${content}=     Update File     ${body}     isolation_level     USER
    ${users}=       Create List     ${FIRST_USER}
    ${content2}=    Update File     ${content}      allowed_users     ${users}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${content2}    headers=${HEADERS}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'
    Sleep    20s
    
Verify isolation_level SERVICE -> USER Update
    [Documentation]   isolation_level user update
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${bucket_name}","visibility":"private"
    Should Contain    ${response.content}    "bucket_name":"${bucket_name}-${FIRST_USER_ID}","visibility":"private"
    ${response}=    Verify Second Bucket
    ${output} = 	Convert To String 	${response.content}
    Should Not Match Regexp    ${output}    "bucket_name":"${bucket_name}-${SECOND_USER_ID}","visibility":"private"

OSCAR Service isolation_level USER -> USER Update with more users
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${content}=     Update File     ${body}     isolation_level     USER
    ${users}=       Create List     ${FIRST_USER}
    Append To List      ${users}    ${SECOND_USER}
    ${content2}=    Update File     ${content}      allowed_users     ${users}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${content2}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'
    Sleep    20s

Verify isolation_level USER -> USER Update with more users
    [Documentation]   isolation_level user update
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${bucket_name}","visibility":"private"
    Should Contain    ${response.content}    "bucket_name":"${bucket_name}-${FIRST_USER_ID}","visibility":"private"
    ${response}=    Verify Second Bucket
    Should Contain    ${response.content}    "bucket_name":"${bucket_name}-${SECOND_USER_ID}","visibility":"private"

OSCAR Service isolation_level USER -> USER Update with less users
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${content}=     Update File     ${body}     isolation_level     USER
    ${users}=       Create List     ${FIRST_USER}
    ${content2}=    Update File     ${content}      allowed_users     ${users}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${content2}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'
    Sleep    20s

Verify isolation_level USER -> USER Update with less users
    [Documentation]   isolation_level user update
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${bucket_name}","visibility":"private"
    Should Contain    ${response.content}    "bucket_name":"${bucket_name}-${FIRST_USER_ID}","visibility":"private"
    ${response}=    Verify Second Bucket
    ${output} = 	Convert To String 	${response.content}
    Should Not Match Regexp    ${output}    "bucket_name":"${bucket_name}-${SECOND_USER_ID}","visibility":"private"

OSCAR Update Service isolation_level user -> service
    [Documentation]  Update a service private -> restricted
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'
    Sleep    20s


Verify isolation_level USER -> SERVICE Update
    [Documentation]   isolation_level user 
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${bucket_name}","visibility":"private"
    ${output} = 	Convert To String 	${response.content}
    Should Not Match Regexp    ${output}    "bucket_name":"${bucket_name}-${FIRST_USER_ID}","visibility":"private"
    ${response}=    Verify Second Bucket
    ${output} = 	Convert To String 	${response.content}
    Should Not Match Regexp    ${output}    "bucket_name":"${bucket_name}-${SECOND_USER_ID}","visibility":"private"

OSCAR Delete Service isolation_level SERVICE
    [Documentation]  Delete the created service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${service_name}   expected_status=204
    ...                       headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204
    Sleep    20s

Verify Delete isolation_level SERVICE
    [Documentation]   isolation_level user 
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    ${output} = 	Convert To String 	${response.content}
    Should Not Match Regexp    ${output}    "bucket_name":"${bucket_name}","visibility":"private"
    Should Not Match Regexp    ${output}    "bucket_name":"${bucket_name}-${FIRST_USER_ID}","visibility":"private"
    ${response}=    Verify Second Bucket
    ${output} = 	Convert To String 	${response.content}
    Should Not Match Regexp    ${output}    "bucket_name":"${bucket_name}-${SECOND_USER_ID}","visibility":"private"

OSCAR Service isolation_level USER Create
    [Documentation]  Create a new service
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${content}=     Update File     ${body}     isolation_level     USER
    ${users}=       Create List     ${FIRST_USER}
    ${content2}=    Update File     ${content}      allowed_users     ${users}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=201    data=${content2}
    ...                     headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201
    Sleep    20s


Verify isolation_level SERVICE Creation
    [Documentation]   isolation_level user update
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${bucket_name}","visibility":"private"
    Should Contain    ${response.content}    "bucket_name":"${bucket_name}-${FIRST_USER_ID}","visibility":"private"
    ${response}=    Verify Second Bucket
    ${output} = 	Convert To String 	${response.content}
    Should Not Match Regexp    ${output}    "bucket_name":"${bucket_name}-${SECOND_USER_ID}","visibility":"private"

OSCAR Delete Service isolation_level USER
    [Documentation]  Delete the created service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${service_name}   expected_status=204
    ...                       headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204
    Sleep    20s
    
Verify isolation_level USER Delete
    [Documentation]   isolation_level user 
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    ${output} = 	Convert To String 	${response.content}
    Should Not Match Regexp    ${output}    "bucket_name":"${bucket_name}","visibility":"private"
    Should Not Match Regexp    ${output}    "bucket_name":"${bucket_name}-${FIRST_USER_ID}","visibility":"private"
    ${response}=    Verify Second Bucket
    ${output} = 	Convert To String 	${response.content}
    Should Not Match Regexp    ${output}    "bucket_name":"${bucket_name}-${SECOND_USER_ID}","visibility":"private"

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
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Set Service File VO    ${service_content}

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


Update File
    [Arguments]    ${content}       ${key}      ${value}
    ${loaded_content}=  yaml.Safe Load  ${content}
    Set To Dictionary    ${loaded_content}      ${key}=${value}
    ${service_content_json}=    Evaluate    json.dumps(${loaded_content})    json
    RETURN      ${service_content_json}


Update File List
    [Arguments]    ${content}       ${key}      ${value}
    ${loaded_content}=  yaml.Safe Load  ${content}
    Set To Dictionary    ${loaded_content}      ${key}=${value}
    ${service_content_json}=    Evaluate    json.dumps(${loaded_content})    json
    RETURN      ${service_content_json}



Verify Second Bucket
    [Documentation]    List all buckets
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=200    headers=${HEADERS2}
    RETURN      ${response}