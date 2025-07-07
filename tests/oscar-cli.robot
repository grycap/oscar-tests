*** Settings ***
Documentation       Tests for the OSCAR CLI against a deployed OSCAR cluster.

Resource            ${CURDIR}/../resources/files.resource
Resource            ${CURDIR}/../resources/token.resource

Suite Teardown      Clean Test Artifacts    True    00-cowsay-invoke-body-downloaded.json
...                     ${DATA_DIR}/custom_service_file.yaml


*** Variables ***
${SERVICE_FILE}     ${DATA_DIR}/00-cowsay.yaml
${SERVICE_NAME}     robot-test-cowsay


*** Test Cases ***
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
    ${result}=    Run Process
    ...    oscar-cli
    ...    apply
    ...    ${DATA_DIR}/custom_service_file.yaml
    ...    stdout=True
    ...    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI List Services
    [Documentation]    Check that OSCAR CLI returns a list of services from the default cluster
    ${result}=    Run Process    oscar-cli    service    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    # Should Contain    ${result.stdout}    ${SERVICE_NAME}

OSCAR CLI Run Services Synchronously With File
    [Documentation]    Wait until the service returns "ROBOT" in its response
    Wait Until Keyword Succeeds
    ...    ${MAX_RETRIES}x
    ...    ${RETRY_INTERVAL}
    ...    Service Should Return ROBOT    ${SERVICE_NAME}    ${INVOKE_FILE}

OSCAR CLI Run Services Synchronously With Prompt
    [Documentation]    Check that OSCAR CLI runs a service (with prompt) synchronously in the default cluster
    ${result}=    Run Process    oscar-cli    service    run    ${SERVICE_NAME}    --text-input
    ...    {"message": "Hello there from AI4EOSC"}    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    Hello

OSCAR CLI Put File
    [Documentation]    Check that OSCAR CLI puts a file in a service's storage provider
    ${result}=    Run Process    oscar-cli    service    put-file    ${SERVICE_NAME}    minio.default
    ...    ${INVOKE_FILE}    ${BUCKET_NAME}/input/${INVOKE_FILE}
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI List Files
    [Documentation]    Check that OSCAR CLI lists files from a service's storage provider path
    ${result}=    Run Process    oscar-cli    service    list-files    ${SERVICE_NAME}
    ...    minio.default    ${BUCKET_NAME}/input/
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    00-cowsay-invoke-body.json

OSCAR CLI Logs List
    [Documentation]    Check that OSCAR CLI lists the logs for a service
    ${result}=    Run Process    oscar-cli    service    logs    list    ${SERVICE_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Get Job Name From Logs
    Should Be Equal As Integers    ${result.rc}    0
    # Should Contain    ${result.stdout}    ${SERVICE_NAME}-

OSCAR CLI Logs Get
    [Documentation]    Check that OSCAR CLI gets the logs from a service's job and wait until job logs contain "ROBOT"
    Wait Until Keyword Succeeds
    ...    ${MAX_RETRIES}x
    ...    ${RETRY_INTERVAL}
    ...    Logs Should Contain ROBOT    ${SERVICE_NAME}    ${JOB_NAME}

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
    ...    ${BUCKET_NAME}/input/${INVOKE_FILE}    00-cowsay-invoke-body-downloaded.json
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Exist    00-cowsay-invoke-body-downloaded.json

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
    [Documentation]    Prepare the service file for service creation
    ${service_content}=    Load Original Service File    ${SERVICE_FILE}
    ${service_content}=    Set Service File VO    ${service_content}
    Save YAML File    ${service_content}    ${DATA_DIR}/custom_service_file.yaml

Service Should Return ROBOT
    [Documentation]    Check that OSCAR CLI runs a service synchronously (with file)
    [Arguments]    ${service_name}    ${invoke_file}
    ${proc}=    Run Process
    ...    oscar-cli    service    run    ${service_name}    --file-input    ${invoke_file}
    ...    stdout=True    stderr=True    shell=True
    Log    STDOUT:\n${proc.stdout}
    Should Be Equal As Integers    ${proc.rc}    0
    Should Contain    ${proc.stdout}    ROBOT

Logs Should Contain ROBOT
    [Documentation]    Check that OSCAR CLI gets the logs from a service's job
    [Arguments]    ${service_name}    ${job_name}
    ${proc}=    Run Process
    ...    oscar-cli    service    logs    get    ${service_name}    ${job_name}
    ...    stdout=True    stderr=True    shell=True
    Log    ${proc.stdout}
    Should Be Equal As Integers    ${proc.rc}    0
    Should Contain    ${proc.stdout}    ROBOT
