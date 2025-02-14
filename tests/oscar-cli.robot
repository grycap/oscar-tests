*** Settings ***
Documentation    Tests for the OSCAR CLI against a deployed OSCAR cluster.

Resource         ${CURDIR}/../resources/resources.resource

Suite Teardown    Remove Files From Tests And Verify    True    00-cowsay-invoke-body-downloaded.json


*** Test Cases ***
Check Valid OIDC Token
    [Documentation]    Get the access token
    ${token}=    Get Access Token
    Check JWT Expiration    ${token}
    VAR    ${TOKEN}    ${token}    scope=SUITE

OSCAR CLI Installed
    [Documentation]    Check that OSCAR CLI is installed
    ${result}=    Run Process    oscar-cli        stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    # Should Contain    ${result.stdout}    apply

OSCAR CLI Cluster Add
    [Documentation]    Check that OSCAR CLI adds a cluster
    ${result}=    Run Process    oscar-cli    cluster    add    robot-oscar-cluster    ${OSCAR_ENDPOINT}
    ...    --oidc-refresh-token  ${REFRESH_TOKEN}    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    successfully

OSCAR CLI Cluster Default
    [Documentation]    Check that OSCAR CLI sets a cluster as default
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
    ${result}=    Run Process    oscar-cli    apply    ${CURDIR}/../data/00-cowsay.yaml    stdout=True    stderr=True
    Sleep    30s
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI List Services
    [Documentation]    Check that OSCAR CLI returns a list of services from the default cluster
    ${result}=    Run Process    oscar-cli    service    list    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    robot-test-cowsay

OSCAR CLI Run Services Synchronously With File
    [Documentation]    Check that OSCAR CLI runs a service (with a file) synchronously in the default cluster
    ${result}=    Run Process    oscar-cli    service    run    robot-test-cowsay    --file-input
    ...           ${CURDIR}/../data/00-cowsay-invoke-body.json    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    Hello

OSCAR CLI Run Services Synchronously With Prompt
    [Documentation]    Check that OSCAR CLI runs a service (with prompt) synchronously in the default cluster
    ${result}=    Run Process    oscar-cli    service    run    robot-test-cowsay    --text-input
    ...    {"message": "Hello there from AI4EOSC"}    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    Hello

OSCAR CLI Put File
    [Documentation]    Check that OSCAR CLI puts a file in a service's storage provider
    ${result}=    Run Process    oscar-cli    service    put-file    robot-test-cowsay    minio.default
    ...    ${CURDIR}/../data/00-cowsay-invoke-body.json    robot-test/input/00-cowsay-invoke-body.json
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI List Files
    [Documentation]    Check that OSCAR CLI lists files from a service's storage provider path
    ${result}=    Run Process    oscar-cli    service    list-files    robot-test-cowsay
    ...    minio.default    robot-test/input/
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    00-cowsay-invoke-body.json

OSCAR CLI Logs List
    [Documentation]    Check that OSCAR CLI lists the logs for a service
    ${result}=    Run Process    oscar-cli    service    logs    list    robot-test-cowsay    stdout=True    stderr=True
    Sleep    15s
    Log    ${result.stdout}
    Get Job Name From Logs
    Should Be Equal As Integers    ${result.rc}    0
    # Should Contain    ${result.stdout}    robot-test-cowsay-

OSCAR CLI Logs Get
    [Documentation]    Check that OSCAR CLI gets the logs from a service's job
    ${result}=    Run Process    oscar-cli    service    logs    get    robot-test-cowsay
    ...    ${JOB_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    Hello

OSCAR CLI Logs Remove
    [Documentation]    Check that OSCAR CLI removes the logs from a service's job
    ${result}=    Run Process    oscar-cli    service    logs    remove    robot-test-cowsay
    ...    ${JOB_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    successfully

OSCAR CLI Get File
    [Documentation]    Check that OSCAR CLI gets a file from a service's storage provider
    ${result}=    Run Process    oscar-cli    service    get-file    robot-test-cowsay    minio.default
    ...    robot-test/input/00-cowsay-invoke-body.json    00-cowsay-invoke-body-downloaded.json
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    File Should Exist    00-cowsay-invoke-body-downloaded.json

OSCAR CLI Services Remove
    [Documentation]    Check that OSCAR CLI removes a service
    ${result}=    Run Process    oscar-cli    service    remove    robot-test-cowsay    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Cluster Remove
    [Documentation]    Check that OSCAR CLI removes a cluster
    ${result}=    Run Process    oscar-cli    cluster    remove    robot-oscar-cluster    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0


*** Keywords ***
Get Job Name From Logs
    [Documentation]    Gets the name of a job from the log's service
    ${job_output}=    Run Process    oscar-cli    service    logs    list    robot-test-cowsay    |
    ...    awk    'NR    \=\=    2    {print    $1}'    shell=True    stdout=True    stderr=True
    Log    ${job_output.stdout}
    VAR    ${JOB_NAME}    ${job_output.stdout}    scope=SUITE
