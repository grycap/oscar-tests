*** Settings ***
Documentation    Tests for the OSCAR CLI against a deployed OSCAR cluster.

Resource         ../resources/resources.resource

Suite Setup       Set OIDC Agent
Suite Teardown    Remove Files From Tests And Verify    True    00-cowsay-invoke-body-downloaded.json


*** Variables ***
${OIDC_SETUP}               oidc-agent --json && eval `oidc-agent-service use` &&
...                         OIDC_ENCRYPTION_PW\=${OIDC_AGENT_PASSWORD} oidc-add ${OIDC_AGENT_ACCOUNT} --pw-env
${ENVIRONMENT_VARIABLES}    export OIDC_SOCK\=/tmp/oidc-agent-service-0/oidc-agent.sock
...                         && export OIDCD_PID_FILE\=/tmp/oidc-agent-service-0/oidc-agent.pid &&


*** Test Cases ***
OSCAR CLI Installed
    [Documentation]    Check that OSCAR CLI is installed
    ${result}=    Run Process    oscar-cli        stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    # Should Contain    ${result.stdout}    apply

OSCAR CLI Cluster Add
    [Documentation]    Check that OSCAR CLI adds a cluster
    ${result}=    Run Process    oscar-cli    cluster    add    robot-oscar-cluster    ${OSCAR_ENDPOINT}
    ...    --oidc-account-name  ${OIDC_AGENT_ACCOUNT}    stdout=True    stderr=True
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
    ${result}=    Run OIDC And Command    oscar-cli cluster info
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
    ${result}=    Run OIDC And Command    oscar-cli apply ./data/00-cowsay.yaml
    Sleep    30s
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI List Services
    [Documentation]    Check that OSCAR CLI returns a list of services from the default cluster
    ${result}=    Run OIDC And Command    oscar-cli service list
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    robot-test-cowsay

# OSCAR CLI Run Services Synchronously
#     [Documentation]    Check that OSCAR CLI runs a service synchronously in the default cluster
#     ${result}=    Run Process    oscar-cli    service    run    robot-test-cowsay    --input
#     ...    ./data/00-cowsay-invoke-body.json    stdout=True    stderr=True
#     Log    ${result.stdout}
#     # Should Be Equal As Integers    ${result.rc}    0
#     Should Contain    ${result.stdout}    Hello

OSCAR CLI Run Services Synchronously
    [Documentation]    Check that OSCAR CLI runs a service synchronously in the default cluster
    VAR    ${command}    oscar-cli service run robot-test-cowsay --text-input
    ...                  '{"message": "Hello there from AI4EOSC"}'
    ${result}=    Run OIDC And Command    ${command}
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    Hello

OSCAR CLI Put File
    [Documentation]    Check that OSCAR CLI puts a file in a service's storage provider
    VAR    ${command}    oscar-cli service put-file robot-test-cowsay minio.default
    ...                  ./data/00-cowsay-invoke-body.json robot-test/input/00-cowsay-invoke-body.json
    ${result}=    Run OIDC And Command    ${command}
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI List Files
    [Documentation]    Check that OSCAR CLI lists files from a service's storage provider path
    ${result}=    Run OIDC And Command    oscar-cli service list-files robot-test-cowsay minio.default robot-test/input/
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    00-cowsay-invoke-body.json

OSCAR CLI Logs List
    [Documentation]    Check that OSCAR CLI lists the logs for a service
    ${result}=    Run OIDC And Command    oscar-cli service logs list robot-test-cowsay
    Sleep    15s
    Log    ${result.stdout}
    Get Job Name From Logs
    Should Be Equal As Integers    ${result.rc}    0
    # Should Contain    ${result.stdout}    robot-test-cowsay-

OSCAR CLI Logs Get
    [Documentation]    Check that OSCAR CLI gets the logs from a service's job
    ${result}=    Run OIDC And Command    oscar-cli service logs get robot-test-cowsay ${JOB_NAME}
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    Hello

OSCAR CLI Logs Remove
    [Documentation]    Check that OSCAR CLI removes the logs from a service's job
    ${result}=    Run OIDC And Command    oscar-cli service logs remove robot-test-cowsay ${JOB_NAME}
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    successfully

OSCAR CLI Get File
    [Documentation]    Check that OSCAR CLI gets a file from a service's storage provider
    VAR    ${command}    oscar-cli service get-file robot-test-cowsay minio.default \
    ...                  robot-test/input/00-cowsay-invoke-body.json \
    ...                  00-cowsay-invoke-body-downloaded.json
    ${result}=    Run OIDC And Command    ${command}
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    File Should Exist    00-cowsay-invoke-body-downloaded.json

OSCAR CLI Services Remove
    [Documentation]    Check that OSCAR CLI removes a service
    ${result}=    Run OIDC And Command    oscar-cli service remove robot-test-cowsay
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Cluster Remove
    [Documentation]    Check that OSCAR CLI removes a cluster
    ${result}=    Run Process    oscar-cli    cluster    remove    robot-oscar-cluster    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0


*** Keywords ***
Set OIDC Agent
    [Documentation]    Check that OSCAR CLI gets a file from a service's storage provider
    Run Process    ${OIDC_SETUP}    shell=True    stdout=True    stderr=True

Run OIDC And Command
    [Documentation]    Check that OSCAR CLI gets a file from a service's storage provider
    [Arguments]    ${command}
    ${result}=    Run Process    ${ENVIRONMENT_VARIABLES} ${command}    shell=True    stdout=True    stderr=True
    RETURN    ${result}

Get Job Name From Logs
    [Documentation]    Check that OSCAR CLI gets a file from a service's storage provider
    ${job_output}=    Run OIDC And Command  oscar-cli service logs list robot-test-cowsay | tail -n 1 | awk '{print $1}'
    Log    ${job_output.stdout}
    VAR    ${JOB_NAME}    ${job_output.stdout}    scope=SUITE
    RETURN    ${JOB_NAME}
