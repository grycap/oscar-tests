*** Settings ***
Documentation       Tests for the OSCAR Manager's API of a deployed OSCAR cluster. Basic endpoint coverage

Resource            ${CURDIR}/../../resources/token.resource
Resource            ${CURDIR}/../../resources/files.resource

Suite Setup         Check Valid OIDC Token
Suite Teardown      Clean Test Artifacts    True    ${DATA_DIR}/service_file.json


*** Variables ***
${SERVICE_NAME}                 robot-test-cowsay
${MOUNT_BUCKET_NAME}            robot-test/mount
${MOUNT_BUCKET_NAME_OTHER}      robot-test-mount

*** Test Cases ***
OSCAR API Health
    [Documentation]    Check API health
    ${response}=    GET    ${OSCAR_ENDPOINT}/health    expected_status=200
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

OSCAR Create Service ${SERVICE_NAME} Mount not Exist
    [Documentation]    Create a new service
    [Tags]    create
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR Verify Bucket ${bucket_name} and Service ${SERVICE_NAME} exist
    [Documentation]    Read a service
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=200
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    "mount":{"storage_provider":"minio.default","path":"robot-test/mount"}
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Log    ${response.content}
    Should Contain    ${response.content}    "bucket_name":"${bucket_name}","visibility":"private"


OSCAR Delete Service ${SERVICE_NAME} 1
    [Documentation]    Delete the created service
    [Tags]    delete
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204


OSCAR Verify Bucket ${bucket_name} still exits and the service ${SERVICE_NAME} dont
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=404
    ...    headers=${HEADERS}
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Log    ${response.content}
    ${output} = 	Convert To String 	${response.content}
    Should Contain    ${output}    "bucket_name":"${bucket_name}","visibility":"private"

Delete Bucket private ${bucket_name} to reset the state
    [Documentation]    Delete a private bucket ${bucket_name}
    [Tags]    Delete    bucket
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/buckets/${bucket_name}    expected_status=204
    ...         headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Create private Bucket ${MOUNT_BUCKET_NAME_OTHER}
    [Documentation]    Create a new private bucket
    ${body}=    Get File    ${DATA_DIR}/bucket.json
    ${body}=  yaml.Safe Load  ${body}
    Set To Dictionary    ${body}    bucket_name=${MOUNT_BUCKET_NAME_OTHER}
    ${body}= 	Convert JSON To String 	${body}
    Log     ${body}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Should Be Equal As Strings    ${response.status_code}    201
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Log    ${response.content}
    Should Contain    ${response.content}    "bucket_name":"${MOUNT_BUCKET_NAME_OTHER}","visibility":"private"
    
    
OSCAR Create Service Mount - where the bucket ${MOUNT_BUCKET_NAME_OTHER} exist and its mine and private
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${body}=  yaml.Safe Load  ${body}
    ${mount} = 	Create Dictionary 	storage_provider=minio.default      path=${MOUNT_BUCKET_NAME_OTHER}
    Set To Dictionary    ${body}    mount=${mount}
    ${body}= 	Convert JSON To String 	${body}
    Log    ${body}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Log    ${response}
    Should Be Equal As Strings    ${response.status_code}    201


OSCAR Verify Bucket ${MOUNT_BUCKET_NAME_OTHER} and Service ${SERVICE_NAME} exist
    [Documentation]    Read a service
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=200
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    "mount":{"storage_provider":"minio.default","path":"${MOUNT_BUCKET_NAME_OTHER}"}
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Log    ${response.content}
    Should Contain    ${response.content}    "bucket_name":"${MOUNT_BUCKET_NAME_OTHER}","visibility":"private"


OSCAR Delete Service ${SERVICE_NAME} 2
    [Documentation]    Delete the created service
    [Tags]    delete
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=404
    ...    headers=${HEADERS}


OSCAR Verify Bucket ${MOUNT_BUCKET_NAME_OTHER} still exits and the service ${SERVICE_NAME} dont
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=404
    ...    headers=${HEADERS}
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Log    ${response.content}
    ${output} = 	Convert To String 	${response.content}
    ${output} = 	Convert To String 	${response.content}
    Should Contain    ${output}    "bucket_name":"${MOUNT_BUCKET_NAME_OTHER}","visibility":"private"


Delete Bucket ${MOUNT_BUCKET_NAME_OTHER} to reset the state
    [Tags]    Delete    bucket
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/buckets/${MOUNT_BUCKET_NAME_OTHER}   expected_status=204   
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204


OSCAR Create Service Mount - where the bucket ${MOUNT_BUCKET_NAME_OTHER} not exist
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${body}=  yaml.Safe Load  ${body}
    ${mount} = 	Create Dictionary 	storage_provider=minio.default      path=${MOUNT_BUCKET_NAME_OTHER}
    Set To Dictionary    ${body}    mount=${mount}
    ${body}= 	Convert JSON To String 	${body}
    Log    ${body}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Log    ${response}
    Should Be Equal As Strings    ${response.status_code}    201


OSCAR Verify Bucket ${MOUNT_BUCKET_NAME_OTHER} and Service Exist
    [Documentation]    Read a service
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=200
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Contain    ${response.content}    "mount":{"storage_provider":"minio.default","path":"${MOUNT_BUCKET_NAME_OTHER}"}
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Log    ${response.content}
    Should Contain    ${response.content}    "bucket_name":"${MOUNT_BUCKET_NAME_OTHER}","visibility":"private"


OSCAR Delete Service ${SERVICE_NAME} 3
    [Documentation]    Delete the created service
    [Tags]    delete
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=404
    ...    headers=${HEADERS}


OSCAR Verify Bucket ${MOUNT_BUCKET_NAME_OTHER} still exits and the service ${SERVICE_NAME} dont after delete
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=404
    ...    headers=${HEADERS}
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Log    ${response.content}
    ${output} = 	Convert To String 	${response.content}
    Should Contain    ${output}    "bucket_name":"${MOUNT_BUCKET_NAME_OTHER}","visibility":"private"

Delete Bucket ${MOUNT_BUCKET_NAME_OTHER}
    [Documentation]    Delete a restricted bucket
    [Tags]    Delete    bucket
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/buckets/${MOUNT_BUCKET_NAME_OTHER}   expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204


Create public Bucket ${MOUNT_BUCKET_NAME_OTHER}
    [Documentation]    Create a new private bucket
    ${body}=    Get File    ${DATA_DIR}/bucket.json
    ${body}=  yaml.Safe Load  ${body}
    Set To Dictionary    ${body}    bucket_name=${MOUNT_BUCKET_NAME_OTHER}
    ${body}=    Set Bucket File Visibility      ${body}     public
    ${body}= 	Convert JSON To String 	${body}
    Log     ${body}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Should Be Equal As Strings    ${response.status_code}    201
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Log    ${response.content}
    Should Contain    ${response.content}    "bucket_name":"${MOUNT_BUCKET_NAME_OTHER}","visibility":"public"


OSCAR Create Service with public Bucket ${MOUNT_BUCKET_NAME_OTHER}. Must answers with error 
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${body}=  yaml.Safe Load  ${body}
    ${mount} = 	Create Dictionary 	storage_provider=minio.default      path=${MOUNT_BUCKET_NAME_OTHER}
    Set To Dictionary    ${body}    mount=${mount}
    ${body}= 	Convert JSON To String 	${body}
    Log    ${body}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=500    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Log    ${response}
    Should Be Equal As Strings    ${response.status_code}    500



Delete Bucket ${MOUNT_BUCKET_NAME_OTHER}. To reset state
    [Documentation]    Delete a restricted bucket
    [Tags]    Delete    bucket
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/buckets/${MOUNT_BUCKET_NAME_OTHER}   expected_status=204   
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204



*** Keywords ***
Prepare Service File
    [Documentation]    Prepare the service file
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Set Service File VO    ${service_content}

    # Extract the inner dictionary (remove 'functions', 'oscar' and 'robot-oscar-cluster')
    VAR    ${modified_content}=    ${service_content}[functions][oscar][0][robot-oscar-cluster]

    # Update the script value
    ${script_value}=    Catenate
    ...    \#!/bin/sh\n\nsleep 5\nif [ \"$INPUT_TYPE\" = \"json\" ]\nthen\n
    ...    jq '.message' \"$INPUT_FILE_PATH\" -r | /usr/games/cowsay\nelse\n
    ...    cat \"$INPUT_FILE_PATH\" | /usr/games/cowsay\n
    ...    cat \"/mnt/${MOUNT_BUCKET_NAME}/${INVOKE_FILE_NAME}\"\nfi\n\
    Set To Dictionary    ${modified_content}    script=${script_value}
    ${mount} = 	Create Dictionary 	storage_provider=minio.default      path=${MOUNT_BUCKET_NAME}
    Set To Dictionary    ${modified_content}    mount=${mount}

    Set To Dictionary    ${modified_content}    script=${script_value}
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${DATA_DIR}/service_file.json    ${service_content_json}

