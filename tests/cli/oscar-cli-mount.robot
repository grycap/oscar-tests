*** Settings ***
Documentation       Tests for the OSCAR CLI mount bucket lifecycle via YAML apply.

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS} 
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/service.resource
Library             Process
Library             String

Suite Setup         Setup Mount CLI Suite
Suite Teardown      Teardown Mount CLI Suite

*** Variables ***
${CLUSTER_NAME}             robot-cli-mount
${SERVICE_BASE}             robot-cli-mnt
${MOUNT_BUCKET_BASE}        robot-cli-mnt-bkt

*** Test Cases ***
OSCAR CLI Installed
    [Documentation]    Check that OSCAR CLI is installed
    ${result}=    Run Process    oscar-cli    stdout=True    stderr=True
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Mount Apply Service With PreExisting Bucket
    [Documentation]    Create a bucket then a service with mount pointing to it
    [Tags]    create
    ${result}=    Run Process    oscar-cli    bucket    create    ${MOUNT_BUCKET_NAME}
    ...    --visibility    private    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Prepare Service File With Mount    ${MOUNT_BUCKET_NAME}
    ${result}=    Run Process    oscar-cli    apply    ${DATA_DIR}/service_file.yaml    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Mount Verify Service And Bucket Exist
    [Documentation]    Verify both the service and the bucket exist
    ${result}=    Run Process    oscar-cli    service    get    ${SERVICE_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${SERVICE_NAME}
    ${result}=    Run Process    oscar-cli    bucket    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${MOUNT_BUCKET_NAME}

OSCAR CLI Mount Delete Service
    [Documentation]    Delete the service, verify the bucket persists
    [Tags]    delete
    ${result}=    Run Process    oscar-cli    service    delete    ${SERVICE_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    ${result}=    Run Process    oscar-cli    bucket    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${MOUNT_BUCKET_NAME}

OSCAR CLI Mount Apply Service With AutoCreate Bucket
    [Documentation]    Create a service with mount where the bucket does not exist yet
    Prepare Service File With Mount    ${MOUNT_BUCKET_NAME}
    ${result}=    Run Process    oscar-cli    apply    ${DATA_DIR}/service_file.yaml    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Mount Verify AutoCreated Bucket
    [Documentation]    Verify the auto-created bucket exists
    Sleep    10s
    ${result}=    Run Process    oscar-cli    bucket    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${MOUNT_BUCKET_NAME}

OSCAR CLI Mount Delete Service And Cleanup Mount Bucket
    [Documentation]    Delete service and the mount bucket
    [Tags]    delete
    ${result}=    Run Process    oscar-cli    service    delete    ${SERVICE_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    ${result}=    Run Process    oscar-cli    bucket    delete    ${MOUNT_BUCKET_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Mount Apply Service With Public Bucket Fails
    [Documentation]    Create a public bucket and try to mount it (expected to fail)
    ${result}=    Run Process    oscar-cli    bucket    create    ${MOUNT_BUCKET_NAME}
    ...    --visibility    public    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Prepare Service File With Mount    ${MOUNT_BUCKET_NAME}
    ${result}=    Run Process    oscar-cli    apply    ${DATA_DIR}/service_file.yaml    stdout=True    stderr=True
    Log    ${result.stdout}
    ${result}=    Run Process    oscar-cli    bucket    delete    ${MOUNT_BUCKET_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}

*** Keywords ***
Setup Mount CLI Suite
    [Documentation]    Set up OIDC token and add cluster
    ${exists}=    Run Keyword And Return Status    Variable Should Exist    ${REFRESH_TOKEN}
    IF  not ${exists}
        Set Refresh Token
    END
    ${result}=    Run Process    oscar-cli    cluster    add    ${CLUSTER_NAME}    ${OSCAR_ENDPOINT}
    ...    --oidc-refresh-token    ${REFRESH_TOKEN}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Contain    ${result.stdout}    successfully
    ${result}=    Run Process    oscar-cli    cluster    default    --set    ${CLUSTER_NAME}
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Contain    ${result.stdout}    successfully
    Assign Random Service Name
    ${mount_bucket_name}=    Generate Random Service Name    ${MOUNT_BUCKET_BASE}
    Set Suite Variable    ${MOUNT_BUCKET_NAME}    ${mount_bucket_name}

Teardown Mount CLI Suite
    [Documentation]    Clean up all artifacts
    Run Keyword And Ignore Error    Remove File    ${DATA_DIR}/service_file.yaml
    Run Keyword And Ignore Error    Run Process    oscar-cli    service    delete    ${SERVICE_NAME}
    ...    stdout=True    stderr=True
    Run Keyword And Ignore Error    Run Process    oscar-cli    bucket    delete    ${MOUNT_BUCKET_NAME}
    ...    stdout=True    stderr=True
    Run Keyword And Ignore Error    Run Process    oscar-cli    cluster    remove    ${CLUSTER_NAME}
    ...    stdout=True    stderr=True

Prepare Service File With Mount
    [Documentation]    Prepare a service file with mount configuration
    [Arguments]    ${mount_bucket}
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Replace String    ${service_content}    name: robot-test-cowsay    name: ${SERVICE_NAME}
    ${service_content}=    Replace String    ${service_content}    robot-test-cowsay/input    ${SERVICE_NAME}/input
    ${service_content}=    Replace String    ${service_content}    robot-test-cowsay/output    ${SERVICE_NAME}/output
    ${service_content}=    Set Service File VO    ${service_content}
    ${output}=    yaml.Dump    ${service_content}
    Create File    ${DATA_DIR}/service_file.yaml    ${output}
