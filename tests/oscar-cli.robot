*** Settings ***
Documentation       Tests for the OSCAR CLI against a deployed OSCAR cluster.

Resource            ${CURDIR}/../${RESOURCE_TO_USE} 
Resource            ${CURDIR}/../resources/files.resource

Suite Teardown      Clean Test Artifacts        True    ${DATA_DIR}/00-cowsay-invoke-body-downloaded.json
...                     ${DATA_DIR}/service_file.yaml


*** Variables ***
${SERVICE_NAME}     robot-test-cowsay
${bucket_name}      robot-test-cowsay


*** Test Cases ***
Refresh Token Exist
    ${exists}=    Run Keyword And Return Status    Variable Should Exist    ${REFRESH_TOKEN}
    IF  not ${exists}
        Set Refresh Token
    END

    
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

OSCAR CLI Cluster Info
    [Documentation]    Check that OSCAR CLI shows info about the default cluster
    ${result}=    Run Process    oscar-cli    cluster    info    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    # Should Contain    ${result.stdout}    kubernetes_version

OSCAR CLI Cluster List
    [Documentation]    Check that OSCAR CLI lists clusters
    ${result}=    Run Process    oscar-cli    cluster    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Contain    ${result.stdout}    robot-oscar-cluster

OSCAR CLI Apply
    [Documentation]    Check that OSCAR CLI creates a service in the default cluster
    [Tags]    create
    Prepare Service File
    ${result}=    Run Process    oscar-cli    apply    ${DATA_DIR}/service_file.yaml    stdout=True    stderr=True
    Sleep    60s
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI List Services
    [Documentation]    Check that OSCAR CLI returns a list of services from the default cluster
    ${result}=    Run Process    oscar-cli    service    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    # Should Contain    ${result.stdout}    ${SERVICE_NAME}

OSCAR CLI Put File
    [Documentation]    Check that OSCAR CLI puts a file in a service's storage provider
    ${result}=    Run Process    oscar-cli    service    put-file    ${SERVICE_NAME}    minio.default
    ...    ${EXECDIR}/data/00-cowsay-invoke-body.json       ${bucket_name}/input/${INVOKE_FILE_NAME}
    ...    stdout=True    stderr=True
    Sleep    10s
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI List Files
    [Documentation]    Check that OSCAR CLI lists files from a service's storage provider path
    ${result}=    Run Process    oscar-cli    service    list-files    ${SERVICE_NAME}
    ...    minio.default    ${bucket_name}/input/
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${INVOKE_FILE_NAME}

OSCAR CLI Logs List
    [Documentation]    Check that OSCAR CLI lists the logs for a service
    ${result}=    Run Process    oscar-cli    service    logs    list    ${SERVICE_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Get Job Name From Logs
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${SERVICE_NAME}-

OSCAR CLI Logs Get
    [Documentation]    Check that OSCAR CLI gets the logs from a service's job
    ${result}=    Run Process    oscar-cli    service    logs    get    ${SERVICE_NAME}
    ...    ${JOB_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    Hello

OSCAR CLI Logs Get Latest
    [Documentation]    Check that OSCAR CLI gets the logs from a service's job
    ${result}=    Run Process    oscar-cli    service    logs    get    ${SERVICE_NAME}
    ...    -l    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    Hello

OSCAR CLI Logs Remove
    [Documentation]    Check that OSCAR CLI removes the logs from a service's job
    ${result}=    Run Process    oscar-cli    service    logs    remove    ${SERVICE_NAME}
    ...    ${JOB_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    successfully

OSCAR CLI Get File
    [Documentation]    Check that OSCAR CLI gets a file from a service's storage provider
    ${result}=    Run Process    oscar-cli    service    get-file    ${SERVICE_NAME}    minio.default
    ...    ${bucket_name}/input/${INVOKE_FILE_NAME}    ${DATA_DIR}/00-cowsay-invoke-body-downloaded.json
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    File Should Exist    ${DATA_DIR}/00-cowsay-invoke-body-downloaded.json

OSCAR CLI Run Services Synchronously With File
    [Documentation]    Check that OSCAR CLI runs a service (with a file) synchronously in the default cluster
    ${result}=    Run Process    oscar-cli    service    run    ${SERVICE_NAME}    --file-input
    ...    ${EXECDIR}/data/00-cowsay-invoke-body.json    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    Hello

OSCAR CLI Run Services Synchronously With Prompt
    [Documentation]    Check that OSCAR CLI runs a service (with prompt) synchronously in the default cluster
    ${result}=    Run Process    oscar-cli    service    run    ${SERVICE_NAME}    --text-input
    ...    {"message": "Hello there from AI4EOSC"}    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    Hello

OSCAR CLI Services Remove
    [Documentation]    Check that OSCAR CLI deletes a service
    [Tags]    delete
    ${result}=    Run Process    oscar-cli    service    delete    ${SERVICE_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Cluster Remove
    [Documentation]    Check that OSCAR CLI removes a cluster
    [Tags]    delete
    ${result}=    Run Process    oscar-cli    cluster    remove    robot-oscar-cluster    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0


*** Keywords ***
Get Job Name From Logs
    [Documentation]    Gets the name of a job from the log's service
    ${job_output}=    Run Process    oscar-cli    service    logs    list    ${SERVICE_NAME}    |
    ...    awk    'NR    \=\=    2    {print    $1}'    shell=True    stdout=True    stderr=True
    Log    ${job_output.stdout}
    VAR    ${JOB_NAME}=    ${job_output.stdout}    scope=SUITE

Prepare Service File
    [Documentation]    Prepare the service file
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Set Service File VO    ${service_content}
    # Convert file content to YAML
    ${output}=    yaml.Dump    ${service_content}
    Create File    ${DATA_DIR}/service_file.yaml    ${output}
