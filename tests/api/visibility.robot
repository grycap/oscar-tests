*** Settings ***
Documentation     Tests for the OSCAR Manager's API of a deployed OSCAR cluster.

Library           RequestsLibrary
Resource          ${CURDIR}/../../resources/token.resource
Resource          ${CURDIR}/../../resources/files.resource

Suite Teardown    Clean Test Artifacts    True    ${DATA_DIR}/service_file.json


*** Variables ***
${service_name}    robot-test-cowsay
${bucket_name}    robot-test-cowsay


*** Test Cases ***
Check Valid OIDC Token
    [Documentation]    Get the access token
    ${token}=    Get Access Token   ${REFRESH_TOKEN}
    Check JWT Expiration    ${token}
    VAR    &{HEADERS}=    Authorization=Bearer ${token}    Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    ${token2}=    Get Access Token   ${REFRESH_TOKEN_SECOND_USER}
    Check JWT Expiration    ${token2}
    VAR    &{HEADERS2}=    Authorization=Bearer ${token2}    Content-Type=text/json    Accept=application/json
    ...    scope=SUITE


OSCAR API Health
    [Documentation]    Check API health
    ${response}=    GET  ${OSCAR_ENDPOINT}/health  expected_status=200
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

OSCAR Create Service
    [Documentation]  Create a new service
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${FIRST_USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services   expected_status=201    data=${body}
    ...                     headers=${HEADERS}
    Log    ${response}  
    Log    ${response.content} 
    Should Be Equal As Strings    ${response.status_code}    201
    Sleep    20s

Verify Visibility of service and check the Bucket is private
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"private"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}

OSCAR Update Service visibility private -> restricted
    [Documentation]  Update a service private -> restricted
    GetService File Update     visibility     restricted
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${FIRST_USER}
    Append To List      ${users}    ${SECOND_USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Sleep    20s
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Verify Visibility of service and check the Bucket is updated to restricted from private
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"restricted"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    Should Contain       ${response}      ${service_name}


OSCAR Update Service visibility restricted -> public
    GetService File Update      visibility     public
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${FIRST_USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Sleep    20s
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Verify Visibility of service and check the Bucket is updated to public from restricted
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"public"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    Should Contain       ${response}      ${service_name}

OSCAR Update Service visibility public -> private
    Get Service File Update      visibility     private
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${FIRST_USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Sleep    20s
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Verify Visibility of service and check the Bucket is updated to private from public
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"private"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}

OSCAR Update Service private -> public
    Get Service File Update      visibility     public
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${FIRST_USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Sleep    20s
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Verify Visibility of service and check the Bucket is updated to public from private
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"public"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    Should Contain       ${response}      ${service_name}

OSCAR Update Service visibility public -> restricted
    [Documentation]  Update a service public -> restricted
    Get Service File Update      visibility     restricted
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${FIRST_USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Sleep    20s
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Verify Visibility of service and check the Bucket is updated to restricted from public
    [Documentation]    Buckets 
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"restricted"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}

OSCAR Update Service visibility restricted -> private
    Get Service File Update      visibility     private
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${FIRST_USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Sleep    20s
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'


Verify Visibility of service and check the Bucket is updated to private from restricted
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"private"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}

OSCAR Delete Service private
    [Documentation]  Delete the created service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${service_name}   expected_status=204
    ...                       headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204
    Sleep    20s

Verify if private Bucket is deleted 
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    ${output} = 	Convert To String 	${response.status_code}
    Should Not Match Regexp    ${output}    ${bucket_name}
    ${response}=    Get Services        ${HEADERS}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}

OSCAR Create Service restricted
    [Documentation]  Create a new service
    Get Service File Update      visibility     restricted
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${FIRST_USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services   expected_status=201    data=${body}
    ...                     headers=${HEADERS}
    Log    ${response}  
    Log    ${response.content} 
    Should Be Equal As Strings    ${response.status_code}    201
    Sleep    20s

Verify Visibility of service and check the Bucket is restricted
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"restricted"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}

OSCAR Delete Service restricted
    [Documentation]  Delete the created service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${service_name}   expected_status=204
    ...                       headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204
    Sleep    20s

Verify if restricted Bucket is deleted 
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    ${output} = 	Convert To String 	${response.status_code}
    Should Not Match Regexp    ${output}    ${bucket_name}
    ${response}=    Get Services        ${HEADERS}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}

OSCAR Create Service public
    [Documentation]  Create a new service
    Get Service File Update      visibility     public
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${FIRST_USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services   expected_status=201    data=${body}
    ...                     headers=${HEADERS}
    Log    ${response}  
    Log    ${response.content} 
    Should Be Equal As Strings    ${response.status_code}    201
    Sleep    20s

Verify Visibility of service and check the Bucket is public
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"public"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    Should Contain       ${response}      ${service_name}


OSCAR Delete Service public
    [Documentation]  Delete the created service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${service_name}   expected_status=204
    ...                       headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204
    Sleep    20s

Verify if public Bucket is deleted 
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    ${output} = 	Convert To String 	${response.status_code}
    Should Not Match Regexp    ${output}    ${bucket_name}
    ${response}=    Get Services        ${HEADERS}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}


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


Get Access Token
    [Documentation]    Retrieve OIDC token using a refresh token
    [Arguments]    ${this_refresh_token}  
    ${result}=    Run Process    curl    -s    -X    POST    '${TOKEN_URL}${TOKEN_ENDPOINT}'    -d
    ...    'grant_type\=refresh_token&refresh_token\=${this_refresh_token}&client_id\=${CLIENT_ID}&scope\=${SCOPE}'
    ...    shell=True    stdout=True    stderr=True
    ${json_output}=    Convert String To Json    ${result.stdout}
    ${access_token}=    Get Value From Json    ${json_output}    $.access_token
    VAR    ${access_token}    ${access_token}[0]
    Log    Access Token: ${access_token}
    VAR    &{HEADERS2}    Authorization=Bearer ${access_token}   Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    RETURN    ${access_token}

Update File
    [Arguments]    ${content}       ${key}      ${value}
    ${loaded_content}=  yaml.Safe Load  ${content}
    Set To Dictionary    ${loaded_content}      ${key}=${value}
    ${service_content_json}=    Evaluate    json.dumps(${loaded_content})    json
    RETURN      ${service_content_json}

Modify Service File
    [Documentation]    Modify the service file with the VO
    ${yaml_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${loaded_content}=  yaml.Safe Load  ${yaml_content}
    Set To Dictionary    ${loaded_content}[functions][oscar][0][robot-oscar-cluster]    vo=${VO}
    RETURN    ${loaded_content}

Get Services
    [Arguments]    ${header_options} 
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services    expected_status=200    headers=${header_options}
    RETURN      ${response.content}
