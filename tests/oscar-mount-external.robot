*** Settings ***
Documentation       Tests for the OSCAR Manager's API of a deployed OSCAR cluster. Basic endpoint coverage

Resource            ${CURDIR}/../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../resources/files.resource

Suite Setup         Check Valid OIDC Token
Suite Teardown      Clean Test Artifacts    True    ${DATA_DIR}/service_file.json


*** Variables ***
${SERVICE_NAME}     robot-test-cowsay
${BUCKET_EXTERNAL}              mount-external-bucket

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

OSCAR API Health of external cluster
    [Documentation]    Check API health
    ${response}=    GET    ${OSCAR_EXTERNAL}/health    expected_status=200
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

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


Verify Bucket Private creation
    [Documentation]    List all buckets and check is private
    ${response}=    External Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    ${output} = 	Convert To String 	${response.content}
    IF    '"bucket_name":"${BUCKET_EXTERNAL}","visibility":"private"' not in '${output}'
        Log     "Not bucket, let's create" 
        ${body}=    Get File    ${DATA_DIR}/bucket.json
        ${body}=  yaml.Safe Load  ${body}
        Set To Dictionary    ${body}    bucket_name=${BUCKET_EXTERNAL}
        ${body}= 	Convert JSON To String 	${body}
        Log     ${body}
        ${response}=    POST    url=${OSCAR_EXTERNAL}/system/buckets    expected_status=201    data=${body}
        ...    headers=${HEADERS}
        Should Be Equal As Strings    ${response.status_code}    201
        ${response}=    External Verify Bucket
        Should Be Equal As Strings    ${response.status_code}    200
        Log    ${response.content}
        Should Contain    ${response.content}    "bucket_name":"${BUCKET_EXTERNAL}","visibility":"private"
    END



OSCAR Create Service Mount - where the bucket ${BUCKET_EXTERNAL} exist and its mine and private
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${body}=  yaml.Safe Load  ${body}
    ${mount} = 	Create Dictionary 	storage_provider=minio.external      path=${BUCKET_EXTERNAL}
    ${external} = 	Create Dictionary 	endpoint=${MINIO_EXTERNAL}            access_key=${USER}
    ...     secret_key=${MINIO_SECRET_KEY}            verify=${True}       region=us-east-1
    ${storage} = 	Create Dictionary
    ${minio} = 	Create Dictionary
    Set To Dictionary    ${body}    mount=${mount}
    Set To Dictionary    ${storage}    external=${external}
    Set To Dictionary    ${minio}    minio=${storage}
    Set To Dictionary    ${body}    storage_providers=${minio}
    ${body}= 	Convert JSON To String 	${body}
    Log    ${body}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services      data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Log    ${response}
    Should Be Equal As Strings    ${response.status_code}    201


OSCAR CLI Put File to external bucket
    [Documentation]    Check that OSCAR CLI puts a file in a service's storage provider
    ${result}=    Run Process    oscar-cli    service        put-file    ${SERVICE_NAME}    minio.external
    ...    ${EXECDIR}/data/00-cowsay-invoke-body.json       ${BUCKET_EXTERNAL}/${INVOKE_FILE_NAME} 
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0


OSCAR CLI List Files
    [Documentation]    Check that OSCAR CLI lists files from a service's storage provider path
    ${result}=    Run Process    oscar-cli    service    list-files    ${SERVICE_NAME}
    ...    minio.external    ${BUCKET_EXTERNAL}
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${INVOKE_FILE_NAME}


OSCAR CLI Put File
    [Documentation]    Check that OSCAR CLI puts a file in a service's storage provider
    ${result}=    Run Process    oscar-cli    service        put-file    ${SERVICE_NAME}    minio
    ...    ${EXECDIR}/data/00-cowsay-invoke-body.json       robot-test/input/${INVOKE_FILE_NAME} 
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Sleep   20s


OSCAR List Jobs
    [Documentation]    List all jobs from a service with their status
    ${list_jobs}=    GET    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}    expected_status=200
    ...    headers=${HEADERS}
    ${jobs_dict}=    Evaluate    dict(${list_jobs.content})
    Get Key From Dictionary    ${jobs_dict}
    Should Contain    ${JOB_NAME}    ${SERVICE_NAME}-
    Sleep   20s

OSCAR Get Logs
    [Documentation]    Get the logs from a job
    ${get_logs}=    GET    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}/${JOB_NAME}    expected_status=200
    ...    headers=${HEADERS}
    Log    ${get_logs.content} 
    Should Contain    ${get_logs.content}    Hello


OSCAR Delete Service ${SERVICE_NAME}
    [Documentation]    Delete the created service
    [Tags]    delete
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=404
    ...    headers=${HEADERS}


Delete Bucket Private
    [Documentation]    Delete a public bucket
    [Tags]    Delete    bucket
    ${response}=    DELETE    url=${OSCAR_EXTERNAL}/system/buckets/${BUCKET_EXTERNAL}     expected_status=204   
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Verify Bucket Public Delete
    [Documentation]  List all buckets 3
    ${response}=    External Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    ${output} = 	Convert To String 	${response.status_code}
    Should Not Match Regexp    ${output}    ${bucket_name}





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
    ...    cat \"/mnt/${BUCKET_EXTERNAL}/${INVOKE_FILE_NAME}\" | /usr/games/cowsay\nfi\n\
    Set To Dictionary    ${modified_content}    script=${script_value}
    ${mount} = 	Create Dictionary 	storage_provider=minio.default      path=${BUCKET_EXTERNAL}
    Set To Dictionary    ${modified_content}    mount=${mount}

    Set To Dictionary    ${modified_content}    script=${script_value}
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${DATA_DIR}/service_file.json    ${service_content_json}


External Verify Bucket
    [Documentation]    List all buckets
    ${response}=    GET    url=${OSCAR_EXTERNAL}/system/buckets    expected_status=200    headers=${HEADERS}
    RETURN      ${response}