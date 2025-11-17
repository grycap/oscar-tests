*** Settings ***
Documentation       Tests for the OSCAR Manager's API of a deployed OSCAR cluster. Basic endpoint coverage

Resource            ${CURDIR}/../${AUTHENTICATION_PROCESS} 
Resource            ${CURDIR}/../resources/files.resource
Resource            ${CURDIR}/../resources/api_call.resource

Suite Setup         Check Valid OIDC Token
Suite Teardown      Clean Test Artifacts    True    ${DATA_DIR}/service_file.json


*** Variables ***
${SERVICE_NAME}     robot-test-cowsay
${MOUNT_BUCKET_NAME}        robot-test/mount
${MOUNT_BUCKET_NAME_RAW}        robot-test
${BUCKET_NAME}        robot-test-cowsay

*** Test Cases ***
Refresh Token Exist
    ${exists}=    Run Keyword And Return Status    Variable Should Exist    ${REFRESH_TOKEN}
    IF  not ${exists}
        Set Refresh Token
    END

OSCAR API Health
    [Documentation]    Check API health
    ${response}=    GET    ${OSCAR_ENDPOINT}/health    expected_status=200
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

OSCAR CLI Installed
    [Documentation]    Check that OSCAR CLI is installed
    ${result}=    Run Process    oscar-cli    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    # Should Contain    ${result.stdout}    apply

OSCAR CLI Cluster Add
    [Documentation]    Check that OSCAR CLI adds a cluster
    [Tags]    create    delete
    ${result}=    Run Process    oscar-cli    cluster    add    robot-oscar-cluster    ${OSCAR_ENDPOINT}
    ...    --oidc-refresh-token    ${REFRESH_TOKEN}    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    successfully

OSCAR CLI Cluster Default
    [Documentation]    Check that OSCAR CLI sets a cluster as default
    [Tags]    create    delete
    ${result}=    Run Process    oscar-cli    cluster    default    --set    robot-oscar-cluster
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    successfully

OSCAR Create Service
    [Documentation]    Create a new service
    [Tags]    create
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201
    Sleep    10s

OSCAR CLI Put File to mount bucket
    [Documentation]    Check that OSCAR CLI puts a file in a service's storage provider
    ${result}=    Run Process    oscar-cli    service    put-file    ${SERVICE_NAME}    minio.default
    ...    ${EXECDIR}/data/00-cowsay-invoke-body.json       ${MOUNT_BUCKET_NAME}/${INVOKE_FILE_NAME}
    ...    stdout=True    stderr=True
    Sleep    10s
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Put File to input bucket
    [Documentation]    Check that OSCAR CLI puts a file in a service's storage provider
    ${result}=    Run Process    oscar-cli    service    put-file    ${SERVICE_NAME}    minio.default
    ...    ${EXECDIR}/data/00-cowsay.yaml       ${BUCKET_NAME}/input/${INVOKE_FILE_NAME}
    ...    stdout=True    stderr=True
    Sleep    30s
    Should Be Equal As Integers    ${result.rc}    0

Check the good execution
    ${list_jobs}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}
    ${jobs_dict}=    Evaluate    dict(${list_jobs.content})
    Get Key From Dictionary    ${jobs_dict["jobs"]}
    Should Contain    ${JOB_NAME}    ${SERVICE_NAME}-
    ${get_logs}=    GET    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}/${JOB_NAME}    expected_status=200
    ...    headers=${HEADERS}
    Sleep    5s
    Should Contain    ${get_logs.content}    Hello

OSCAR Delete Service
    [Documentation]    Delete the created service
    [Tags]    delete
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204


OSCAR CLI Cluster Remove
    [Documentation]    Check that OSCAR CLI removes a cluster
    [Tags]    delete
    ${result}=    Run Process    oscar-cli    cluster    remove    robot-oscar-cluster    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

Delete Bucket ${MOUNT_BUCKET_NAME_RAW}. To reset state
    [Documentation]    Delete a restricted bucket
    [Tags]    Delete    bucket
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/buckets/${MOUNT_BUCKET_NAME_RAW}   expected_status=204   
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
    ...    \#!/bin/sh\n\nsleep 10\nif [ \"$INPUT_TYPE\" = \"json\" ]\nthen\n
    ...    jq '.message' \"$INPUT_FILE_PATH\" -r | /usr/games/cowsay\nelse\n
    ...    cat \"$INPUT_FILE_PATH\" | /usr/games/cowsay\n
    ...    cat \"/mnt/${MOUNT_BUCKET_NAME}/${INVOKE_FILE_NAME}\"\nfi\n\
    Set To Dictionary    ${modified_content}    script=${script_value}
    ${mount} = 	Create Dictionary 	storage_provider=minio.default      path=${MOUNT_BUCKET_NAME}
    Set To Dictionary    ${modified_content}    mount=${mount}

    Set To Dictionary    ${modified_content}    script=${script_value}
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${DATA_DIR}/service_file.json    ${service_content_json}

