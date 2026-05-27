*** Settings ***
Documentation       Tests for the OSCAR CLI service deployment status and logs commands.

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS} 
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/service.resource
Library             Process

Suite Setup         Setup Deployment CLI Suite
Suite Teardown      Teardown Deployment CLI Suite

*** Variables ***
${CLUSTER_NAME}             robot-cli-deploy
${SERVICE_BASE}             robot-cli-dep
${SERVICE_TIMEOUT}          180s
${SERVICE_RETRY_INTERVAL}   10s

*** Test Cases ***
OSCAR CLI Installed
    [Documentation]    Check that OSCAR CLI is installed
    ${result}=    Run Process    oscar-cli    stdout=True    stderr=True
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Cluster Add
    [Documentation]    Check that OSCAR CLI adds a cluster
    [Tags]    create    delete
    ${result}=    Run Process    oscar-cli    cluster    add    robot-oscar-cluster    ${OSCAR_ENDPOINT}
    ...    --oidc-refresh-token    ${REFRESH_TOKEN}    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    successfully

OSCAR CLI Deploy Apply Service
    [Documentation]    Create a service for deployment testing
    [Tags]    create
    Prepare Deployment Service File
    ${result}=    Run Process    oscar-cli    apply    ${DATA_DIR}/service_file.yaml    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Deploy Wait For Ready
    [Documentation]    Wait for the service to be ready
    ${exists}=    Run Keyword And Return Status
    ...    Wait Until Keyword Succeeds    ${SERVICE_TIMEOUT}    ${SERVICE_RETRY_INTERVAL}
    ...    Service Should Be Deployed And Ready    ${SERVICE_NAME}
    Should Be True    ${exists}    Service did not become ready within ${SERVICE_TIMEOUT}

OSCAR CLI Deploy Status
    [Documentation]    Get deployment status and validate output
    ${result}=    Run Process    oscar-cli    service    deployment    status    ${SERVICE_NAME}
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    state
    Should Contain    ${result.stdout}    active_instances

OSCAR CLI Deploy Logs
    [Documentation]    Get deployment logs and validate output
    ${result}=    Run Process    oscar-cli    service    deployment    logs    ${SERVICE_NAME}
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Deploy Delete Service
    [Documentation]    Delete the service created for deployment testing
    [Tags]    delete
    ${result}=    Run Process    oscar-cli    service    delete    ${SERVICE_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

*** Keywords ***
Setup Deployment CLI Suite
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

Teardown Deployment CLI Suite
    [Documentation]    Clean up service files and cluster
    Run Keyword And Ignore Error    Remove File    ${DATA_DIR}/service_file.yaml
    Run Keyword And Ignore Error    Run Process    oscar-cli    service    delete    ${SERVICE_NAME}
    ...    stdout=True    stderr=True
    Run Keyword And Ignore Error    Run Process    oscar-cli    cluster    remove    robot-oscar-cluster
    ...    stdout=True    stderr=True
    Run Keyword And Ignore Error    Run Process    oscar-cli    cluster    remove    ${CLUSTER_NAME}
    ...    stdout=True    stderr=True

Service Should Be Deployed And Ready
    [Documentation]    Check if a service is ready via service get
    [Arguments]    ${service_name}
    ${result}=    Run Process    oscar-cli    service    get    ${service_name}
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${service_name}
    Should Not Contain    ${result.stdout}    error

Prepare Deployment Service File
    [Documentation]    Prepare a lightweight service for deployment testing
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Replace String    ${service_content}    name: robot-test-cowsay    name: ${SERVICE_NAME}
    ${service_content}=    Replace String    ${service_content}    robot-test-cowsay/input    ${SERVICE_NAME}/input
    ${service_content}=    Replace String    ${service_content}    robot-test-cowsay/output    ${SERVICE_NAME}/output
    ${service_content}=    Set Service File VO    ${service_content}
    ${output}=    yaml.Dump    ${service_content}
    Create File    ${DATA_DIR}/service_file.yaml    ${output}
