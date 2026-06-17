*** Settings ***
Documentation       Tests for the OSCAR CLI service visibility via YAML apply.

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS} 
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/service.resource
Library             Process
Library             String

Suite Setup         Setup Visibility CLI Suite
Suite Teardown      Teardown Visibility CLI Suite

*** Variables ***
${CLUSTER_NAME}     robot-oscar-cluster
${SERVICE_BASE}     robot-cli-vis

*** Test Cases ***
OSCAR CLI Installed
    [Documentation]    Check that OSCAR CLI is installed
    ${result}=    Run Process    oscar-cli    stdout=True    stderr=True
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Visibility Apply Private Service
    [Documentation]    Create a service with private visibility
    [Tags]    create
    Prepare Service File With Visibility    private
    ${result}=    Run Process    oscar-cli    apply    ${DATA_DIR}/service_file.yaml    stdout=True    stderr=True
    Log    ${result.stdout}     console=yes
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Visibility Verify Private Service
    [Documentation]    Verify the private service exists
    ${result}=    Run Process    oscar-cli    service    get    ${SERVICE_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${SERVICE_NAME}

OSCAR CLI Visibility Update To Public
    [Documentation]    Update service visibility to public
    [Tags]    update
    Prepare Service File With Visibility    public
    ${result}=    Run Process    oscar-cli    apply    ${DATA_DIR}/service_file.yaml    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Visibility Update To Restricted
    [Documentation]    Update service visibility to restricted
    Prepare Service File With Visibility    restricted
    ${result}=    Run Process    oscar-cli    apply    ${DATA_DIR}/service_file.yaml    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Visibility Update Back To Private
    [Documentation]    Update service visibility back to private
    Prepare Service File With Visibility    private
    ${result}=    Run Process    oscar-cli    apply    ${DATA_DIR}/service_file.yaml    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Visibility Delete Service
    [Documentation]    Delete the service
    [Tags]    delete
    ${result}=    Run Process    oscar-cli    service    delete    ${SERVICE_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

*** Keywords ***
Setup Visibility CLI Suite
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

Teardown Visibility CLI Suite
    [Documentation]    Clean up service files and cluster
    Run Keyword And Ignore Error    Remove File    ${DATA_DIR}/service_file.yaml
    Run Keyword And Ignore Error    Run Process    oscar-cli    service    delete    ${SERVICE_NAME}
    ...    stdout=True    stderr=True
    Run Keyword And Ignore Error    Run Process    oscar-cli    cluster    remove    ${CLUSTER_NAME}
    ...    stdout=True    stderr=True

Prepare Service File With Visibility
    [Documentation]    Prepare a service file with the given visibility
    [Arguments]    ${visibility}
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Replace String    ${service_content}    name: robot-test-cowsay    name: ${SERVICE_NAME}
    ${service_content}=    Replace String    ${service_content}    robot-test-cowsay/input    ${SERVICE_NAME}/input
    ${service_content}=    Replace String    ${service_content}    robot-test-cowsay/output    ${SERVICE_NAME}/output
    ${service_content}=    Set Service File VO    ${service_content}
    ${output}=    yaml.Dump    ${service_content}
    Create File    ${DATA_DIR}/service_file.yaml    ${output}
