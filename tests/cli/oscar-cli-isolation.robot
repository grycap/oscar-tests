*** Settings ***
Documentation       Tests for the OSCAR CLI service isolation levels via YAML apply.

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS} 
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/service.resource
Library             Process
Library             String

Suite Setup         Setup Isolation CLI Suite
Suite Teardown      Teardown Isolation CLI Suite

*** Variables ***
${CLUSTER_NAME}     robot-cli-isolation
${SERVICE_BASE}     robot-cli-iso

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

OSCAR CLI Isolation Apply With SERVICE Level
    [Documentation]    Create a service with SERVICE isolation level
    [Tags]    create
    Prepare Service File With Isolation    SERVICE    ${EMPTY}
    ${result}=    Run Process    oscar-cli    apply    ${DATA_DIR}/service_file.yaml    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Isolation Verify SERVICE Level
    [Documentation]    Verify the service has SERVICE isolation level
    ${result}=    Run Process    oscar-cli    service    get    ${SERVICE_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${SERVICE_NAME}

OSCAR CLI Isolation Update To USER Level
    [Documentation]    Update service isolation level to USER
    [Tags]    update
    Prepare Service File With Isolation    USER    ${EMPTY}
    ${result}=    Run Process    oscar-cli    apply    ${DATA_DIR}/service_file.yaml    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Isolation Verify USER Level
    [Documentation]    Verify the service now has USER isolation
    Sleep    20s
    ${result}=    Run Process    oscar-cli    bucket    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Isolation Update Back To SERVICE Level
    [Documentation]    Update service isolation level back to SERVICE
    Prepare Service File With Isolation    SERVICE    ${EMPTY}
    ${result}=    Run Process    oscar-cli    apply    ${DATA_DIR}/service_file.yaml    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Isolation Delete Service
    [Documentation]    Delete the service
    [Tags]    delete
    ${result}=    Run Process    oscar-cli    service    delete    ${SERVICE_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

*** Keywords ***
Setup Isolation CLI Suite
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

Teardown Isolation CLI Suite
    [Documentation]    Clean up service files and cluster
    Run Keyword And Ignore Error    Remove File    ${DATA_DIR}/service_file.yaml
    Run Keyword And Ignore Error    Run Process    oscar-cli    service    delete    ${SERVICE_NAME}
    ...    stdout=True    stderr=True
    Run Keyword And Ignore Error    Run Process    oscar-cli    cluster    remove    robot-oscar-cluster
    ...    stdout=True    stderr=True
    Run Keyword And Ignore Error    Run Process    oscar-cli    cluster    remove    ${CLUSTER_NAME}
    ...    stdout=True    stderr=True

Prepare Service File With Isolation
    [Documentation]    Prepare a service file with the given isolation level
    [Arguments]    ${isolation_level}    ${allowed_users}
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Replace String    ${service_content}    name: robot-test-cowsay    name: ${SERVICE_NAME}
    ${service_content}=    Replace String    ${service_content}    robot-test-cowsay/input    ${SERVICE_NAME}/input
    ${service_content}=    Replace String    ${service_content}    robot-test-cowsay/output    ${SERVICE_NAME}/output
    ${service_content}=    Set Service File VO    ${service_content}
    ${service_content}=    Set Service File Isolation Level    ${service_content}    ${isolation_level}
    IF    '${allowed_users}' != '${EMPTY}'
        ${service_content}=    Set Service File Allowed Users    ${service_content}    ${allowed_users}
    END
    ${output}=    yaml.Dump    ${service_content}
    Create File    ${DATA_DIR}/service_file.yaml    ${output}
