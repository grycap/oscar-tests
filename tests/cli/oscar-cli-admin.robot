*** Settings ***
Documentation       Tests for the OSCAR CLI with username/password authentication against a deployed OSCAR cluster.

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS} 
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/service.resource
Library             String
Library             Process

Suite Setup         Checks Valids OIDC Token
Suite Teardown      Clean Test Artifacts            ${DATA_DIR}/00-cowsay-invoke-body-downloaded.json
...                     ${DATA_DIR}/service_file.yaml


*** Variables ***
${SERVICE_BASE}     robot-cli-admin
${VOLUME_NAME}      robot-cli-vol-admin


*** Test Cases ***
Admin Credentials Exist
    ${exists}=    Run Keyword And Return Status    Variable Should Exist    ${OSCAR_USER}
    IF  not ${exists}
        Set Admin Credentials
    END
    Assign Random Service Name
    Set Suite Variable    ${bucket_name}    ${SERVICE_NAME}

    
OSCAR CLI Installed
    [Documentation]    Check that OSCAR CLI is installed
    ${result}=    Run Process    oscar-cli    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Cluster Add
    [Documentation]    Check that OSCAR CLI adds a cluster with username/password
    [Tags]    create    delete
    ${result}=    Run Process    oscar-cli    cluster    add    robot-oscar-cluster-admin    ${OSCAR_ENDPOINT}
    ...     ${OSCAR_USER}       ${OSCAR_PASSWORD}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Contain    ${result.stdout}    successfully

OSCAR CLI Cluster Default
    [Documentation]    Check that OSCAR CLI sets a cluster as default
    [Tags]    create    delete
    ${result}=    Run Process    oscar-cli    cluster    default    --set    robot-oscar-cluster-admin
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Contain    ${result.stdout}    successfully

OSCAR CLI Cluster Info
    [Documentation]    Check that OSCAR CLI shows info about the default cluster
    ${result}=    Run Process    oscar-cli    cluster    info    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Cluster List
    [Documentation]    Check that OSCAR CLI lists clusters
    ${result}=    Run Process    oscar-cli    cluster    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Contain    ${result.stdout}    robot-oscar-cluster-admin

OSCAR CLI Health
    [Documentation]    Check that OSCAR CLI shows health status
    ${result}=    Run Process    oscar-cli    health    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    Health:

OSCAR CLI Health JSON
    [Documentation]    Check that OSCAR CLI shows health status in JSON
    ${result}=    Run Process    oscar-cli    health    --output    json    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    status

OSCAR CLI Metrics Summary
    [Documentation]    Check that OSCAR CLI shows metrics summary
    ${result}=    Run Process    oscar-cli    metrics    summary    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    services_count_active

OSCAR CLI Quota Get
    [Documentation]    Check that OSCAR CLI gets the user quota
    ${result}=    Run Process    oscar-cli    quota    get      ${USER}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Volume List
    [Documentation]    Check that OSCAR CLI lists volumes
    ${result}=    Run Process    oscar-cli    volume    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Volume Create
    [Documentation]    Check that OSCAR CLI creates a volume
    ${result}=    Run Process    oscar-cli    volume    create    ${VOLUME_NAME}    --size    1Gi    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Volume Get
    [Documentation]    Check that OSCAR CLI gets a volume
    ${result}=    Run Process    oscar-cli    volume    get    ${VOLUME_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${VOLUME_NAME}

OSCAR CLI Volume Delete
    [Documentation]    Check that OSCAR CLI deletes a volume
    ${result}=    Run Process    oscar-cli    volume    delete    ${VOLUME_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Metrics Breakdown
    [Documentation]    Check that OSCAR CLI shows metrics breakdown
    ${result}=    Run Process    oscar-cli    metrics    breakdown      --group-by      service    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Cluster Status
    [Documentation]    Check that OSCAR CLI shows cluster status
    ${result}=    Run Process    oscar-cli    cluster    status    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

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

OSCAR CLI Service Deployment Status
    [Documentation]    Check that OSCAR CLI shows service deployment status
    ${result}=    Run Process    oscar-cli    service    deployment    status    ${SERVICE_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    state

OSCAR CLI Service Deployment Logs
    [Documentation]    Check that OSCAR CLI shows service deployment logs
    ${result}=    Run Process    oscar-cli    service    deployment    logs    ${SERVICE_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Metrics Service
    [Documentation]    Check that OSCAR CLI shows metrics for a service
    ${result}=    Run Process    oscar-cli    metrics    service    ${SERVICE_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Put File
    [Documentation]    Check that OSCAR CLI puts a file in a service's storage provider
    ${result}=    Run Process    oscar-cli    service    put-file    ${SERVICE_NAME}    minio.default
    ...    ${EXECDIR}/data/00-cowsay-invoke-body.json       ${bucket_name}/input/${INVOKE_FILE_NAME}
    ...    stdout=True    stderr=True
    Sleep    30s
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI List Files
    [Documentation]    Check that OSCAR CLI lists files from a service's storage provider path
    ${result}=    Run Process    oscar-cli    service    list-files    ${SERVICE_NAME}
    ...    minio.default    ${bucket_name}/input/
    Log    ${result.stdout}
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
    Should Contain    ${result.stdout}    Hello

OSCAR CLI Logs Get Latest
    [Documentation]    Check that OSCAR CLI gets the logs from a service's job
    ${result}=    Run Process    oscar-cli    service    logs    get    ${SERVICE_NAME}
    ...    -l    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Contain    ${result.stdout}    Hello

OSCAR CLI Logs Remove
    [Documentation]    Check that OSCAR CLI removes the logs from a service's job
    ${result}=    Run Process    oscar-cli    service    logs    remove    ${SERVICE_NAME}
    ...    ${JOB_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Contain    ${result.stdout}    successfully

OSCAR CLI Get File
    [Documentation]    Check that OSCAR CLI gets a file from a service's storage provider
    ${result}=    Run Process    oscar-cli    service    get-file    ${SERVICE_NAME}    minio.default
    ...    ${bucket_name}/input/${INVOKE_FILE_NAME}    ${DATA_DIR}/00-cowsay-invoke-body-downloaded.json
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    File Should Exist    ${DATA_DIR}/00-cowsay-invoke-body-downloaded.json

OSCAR CLI Run Services Synchronously With File
    [Documentation]    Check that OSCAR CLI runs a service (with a file) synchronously in the default cluster
    ${result}=    Run Process    oscar-cli    service    run    ${SERVICE_NAME}    --file-input
    ...    ${EXECDIR}/data/00-cowsay-invoke-body.json    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Contain    ${result.stdout}    Hello

OSCAR CLI Run Services Synchronously With Prompt
    [Documentation]    Check that OSCAR CLI runs a service (with prompt) synchronously in the default cluster
    ${result}=    Run Process    oscar-cli    service    run    ${SERVICE_NAME}    --text-input
    ...    {"message": "Hello there from AI4EOSC"}    stdout=True    stderr=True
    Log    ${result.stdout}
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
    ${result}=    Run Process    oscar-cli    cluster    remove    robot-oscar-cluster-admin    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0


*** Keywords ***
Set Admin Credentials
    [Documentation]    Decode BASIC_USER and set OSCAR_USER and OSCAR_PASSWORD
    ${decoded}=    Evaluate    base64.b64decode('${BASIC_USER}').decode('utf-8')    modules=base64
    @{credentials}=    Split String    ${decoded}    :
    VAR    ${OSCAR_USER}=    ${credentials}[0]    scope=SUITE
    VAR    ${OSCAR_PASSWORD}=    ${credentials}[1]    scope=SUITE
    Set Global Variable    ${OSCAR_USER}
    Set Global Variable    ${OSCAR_PASSWORD}

Get Job Name From Logs
    [Documentation]    Gets the name of a job from the log's service
    ${job_output}=    Run Process    oscar-cli    service    logs    list    ${SERVICE_NAME}    |
    ...    awk    'NR    \=\=    2    {print    $1}'    shell=True    stdout=True    stderr=True
    Log    ${job_output.stdout}
    VAR    ${JOB_NAME}=    ${job_output.stdout}    scope=SUITE

Prepare Service File
    [Documentation]    Prepare the service file
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Replace String    ${service_content}    robot-oscar-cluster:    robot-oscar-cluster-admin:
    ${service_content}=    Replace String    ${service_content}    name: robot-test-cowsay    name: ${SERVICE_NAME}
    ${service_content}=    Replace String    ${service_content}    robot-test-cowsay/input    ${SERVICE_NAME}/input
    ${service_content}=    Replace String    ${service_content}    robot-test-cowsay/output    ${SERVICE_NAME}/output
    ${service_content}=    Set Service File VO    ${service_content}
    ${output}=    yaml.Dump    ${service_content}
    Create File    ${DATA_DIR}/service_file.yaml    ${output}