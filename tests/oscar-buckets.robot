*** Settings ***
Documentation     Tests for the OSCAR Manager's API of a deployed OSCAR cluster.

Library           RequestsLibrary
Resource          ${CURDIR}/../resources/files.resource
Resource          ${CURDIR}/../resources/token.resource

Suite Setup       Check Valid OIDC Token
Suite Teardown    Clean Test Artifacts    True    ${DATA_DIR}/service_file.json


*** Variables ***
${bucket_name}    robot-test

*** Test Cases ***
OSCAR API Health
    [Documentation]    Check API health
    ${response}=    GET  ${OSCAR_ENDPOINT}/health  expected_status=200
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

Create Bucket Private
    [Documentation]    Create a new private bucket
    [Tags]    create    bucket
    ${body}=    Get File    ${DATA_DIR}/bucket.json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

Verify Bucket Private creation
    [Documentation]    List all buckets and check is private
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"private"

Update Bucket from Private -> to Restricted
    [Documentation]    Update Private bucket -> Restricted
    [Tags]    update    bucket
    ${body}=    Get File    ${DATA_DIR}/bucket.json
    ${body}=  yaml.Safe Load  ${body}
    ${body}=    Set Bucket File Visibility      ${body}     restricted
    ${body}=    Set Bucket File Allowed Users   ${body}     ${first_user}
    ${body}= 	Convert JSON To String 	${body}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=204    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Verify Bucket Update from Private -> to Restricted
    [Documentation]    List all buckets is restricted
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"restricted"

Update Bucket from Restricted -> to Public
    [Documentation]    Update Restricted bucket -> Public
    [Tags]    update    bucket
    ${body}=    Get File    ${DATA_DIR}/bucket.json
    ${body}=  yaml.Safe Load  ${body}
    ${body}=    Set Bucket File Visibility      ${body}     public
    ${body}= 	Convert JSON To String 	${body}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=204    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Verify Bucket Update from Restricted -> to Public
    [Documentation]    List all buckets is public
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"public"



Update Bucket from Public -> to Private
    [Documentation]    Update public bucket -> private
    [Tags]    update    bucket
    ${body}=    Get File    ${DATA_DIR}/bucket.json
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=204    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204


Verify Bucket Update from Public -> to Private
    [Documentation]    List all buckets is private
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"private"


Update Bucket from Private -> to Public
    [Documentation]    Update private bucket -> public
    [Tags]    update    bucket
    ${body}=    Get File    ${DATA_DIR}/bucket.json
    ${body}=  yaml.Safe Load  ${body}
    ${body}=    Set Bucket File Visibility      ${body}     public
    ${body}= 	Convert JSON To String 	${body}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=204    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Verify Bucket Update from Private -> to Public
    [Documentation]    List all buckets is public
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"public"


Update Bucket from Public -> to Restricted
    [Documentation]    Update public bucket -> restricted
    [Tags]    update    bucket
    ${body}=    Get File    ${DATA_DIR}/bucket.json
    ${body}=  yaml.Safe Load  ${body}
    ${body}=    Set Bucket File Visibility      ${body}     restricted
    ${body}=    Set Bucket File Allowed Users   ${body}     ${first_user}
    ${body}= 	Convert JSON To String 	${body}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=204    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Verify Bucket Update from Public -> to Restricted 
    [Documentation]    List all buckets is restricted
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"restricted"


Update Bucket from Restricted -> to Private
    [Documentation]    Update restricted bucket -> private
    [Tags]    update    bucket
    ${body}=    Get File    ${DATA_DIR}/bucket.json
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=204    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Verify Bucket Update from Restricted -> to Private
    [Documentation]    List all buckets is private
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"private"

Delete Bucket Private
    [Documentation]    Delete a private bucket
    [Tags]    Delete    bucket
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/buckets/${bucket_name}    expected_status=204   
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Verify Bucket Private Delete
    [Documentation]    List all buckets 2
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    ${output} = 	Convert To String 	${response.status_code}
    Should Not Match Regexp    ${output}    ${bucket_name}

Create Bucket Restricted
    [Documentation]    Create a new restricted bucket
    [Tags]    create    bucket
    ${body}=    Get File    ${DATA_DIR}/bucket.json
    ${body}=  yaml.Safe Load  ${body}
    ${body}=    Set Bucket File Visibility      ${body}     restricted
    ${body}=    Set Bucket File Allowed Users   ${body}     ${first_user}
    ${body}= 	Convert JSON To String 	${body}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

Verify Bucket Restricted creation
    [Documentation]    List all buckets and check is private
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"restricted"


Delete Bucket Restricted
    [Documentation]    Delete a restricted bucket
    [Tags]    Delete    bucket
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/buckets/${bucket_name}    expected_status=204   
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Verify Bucket Restricted Delete
    [Documentation]  List all buckets 3
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    ${output} = 	Convert To String 	${response.status_code}
    Should Not Match Regexp    ${output}    ${bucket_name}

Create Bucket Public
    [Documentation]    Create a new public bucket
    [Tags]    create    bucket
    ${body}=    Get File    ${DATA_DIR}/bucket.json
    ${body}=  yaml.Safe Load  ${body}
    ${body}=    Set Bucket File Visibility      ${body}     public
    ${body}= 	Convert JSON To String 	${body}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

Verify Bucket Public creation
    [Documentation]    List all buckets and check is private
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"public"

Delete Bucket Public
    [Documentation]    Delete a public bucket
    [Tags]    Delete    bucket
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/buckets/${bucket_name}    expected_status=204   
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Verify Bucket Public Delete
    [Documentation]  List all buckets 3
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    ${output} = 	Convert To String 	${response.status_code}
    Should Not Match Regexp    ${output}    ${bucket_name}


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
