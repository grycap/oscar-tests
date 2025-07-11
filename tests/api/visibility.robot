*** Settings ***
Documentation     Tests for the OSCAR Manager's API of a deployed OSCAR cluster.

Library           RequestsLibrary
Resource          ${CURDIR}/../../resources/token.resource
Resource          ${CURDIR}/../../resources/files.resource

Suite Setup       Check Valid OIDC Token
Suite Teardown    Clean Test Artifacts    True    ${DATA_DIR}/service_file.json


*** Variables ***
${service_name}    robot-test-cowsay
${bucket_name}    robot-test


*** Test Cases ***
OSCAR API Health
    [Documentation]    Check API health
    ${response}=    GET  ${OSCAR_ENDPOINT}/health  expected_status=200
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

OSCAR Create Service
    [Documentation]  Create a new service
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${first_user}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services   expected_status=201    data=${body}
    ...                     headers=${HEADERS}
    Log    ${response}  
    Log    ${response.content} 
    Should Be Equal As Strings    ${response.status_code}    201

Verify Bucket update
    [Documentation]   Buckets is private 1
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"private"

OSCAR Update Service visibility private -> restricted
    [Documentation]  Update a service private -> restricted
    GetService File Update     visibility     restricted
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${first_user}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Sleep    2s
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Verify Bucket update is restricted
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"restricted"

OSCAR Update Service visibility restricted -> public
    GetService File Update      visibility     public
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${first_user}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Sleep    2s
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Verify Bucket update is public
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"public"

OSCAR Update Service visibility public -> private
    Get Service File Update      visibility     private
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${first_user}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Sleep    2s
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Verify Bucket is private 2
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"private"

OSCAR Update Service private -> public
    Get Service File Update      visibility     public
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${first_user}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Sleep    2s
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Verify Bucket is public 2
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"public"

OSCAR Update Service visibility public -> restricted
    [Documentation]  Update a service public -> restricted
    Get Service File Update      visibility     restricted
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${first_user}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Sleep    2s
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Verify Bucket is restricted 2
    [Documentation]    Buckets 
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"restricted"

OSCAR Update Service visibility restricted -> private
    Get Service File Update      visibility     private
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${first_user}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Sleep    2s
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'


Verify Bucket update is private 3
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"private"

OSCAR Delete Service private
    [Documentation]  Delete the created service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${service_name}   expected_status=204
    ...                       headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Verify Bucket delete 1
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    ${output} = 	Convert To String 	${response.status_code}
    Should Not Match Regexp    ${output}    ${bucket_name}

OSCAR Create Service restricted
    [Documentation]  Create a new service
    Get Service File Update      visibility     restricted
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${first_user}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services   expected_status=201    data=${body}
    ...                     headers=${HEADERS}
    Log    ${response}  
    Log    ${response.content} 
    Should Be Equal As Strings    ${response.status_code}    201

Verify Bucket restricted
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"restricted"


delete restricted
    [Documentation]  Delete the created service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${service_name}   expected_status=204
    ...                       headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Verify Bucket delete 2
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    ${output} = 	Convert To String 	${response.status_code}
    Should Not Match Regexp    ${output}    ${bucket_name}

OSCAR Create Service public
    [Documentation]  Create a new service
    Get Service File Update      visibility     public
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${first_user}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services   expected_status=201    data=${body}
    ...                     headers=${HEADERS}
    Log    ${response}  
    Log    ${response.content} 
    Should Be Equal As Strings    ${response.status_code}    201

Verify Bucket public
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_path":"${bucket_name}","visibility":"public"


OSCAR Delete Service public
    [Documentation]  Delete the created service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${service_name}   expected_status=204
    ...                       headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Verify Bucket delete 3
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