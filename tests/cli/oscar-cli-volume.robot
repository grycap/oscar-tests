*** Settings ***
Documentation       Tests for the OSCAR CLI volume commands (CRUD).

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS} 
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/service.resource
Library             Process

Suite Setup         Setup Volume CLI Suite
Suite Teardown      Teardown Volume CLI Suite

*** Variables ***
${CLUSTER_NAME}     robot-cli-volume
${VOLUME_NAME}      robot-cli-vol
${SERVICE_BASE}     robot-cli-vol-svc

*** Test Cases ***
OSCAR CLI Installed
    [Documentation]    Check that OSCAR CLI is installed
    ${result}=    Run Process    oscar-cli    stdout=True    stderr=True
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Volume List
    [Documentation]    Check that OSCAR CLI lists volumes
    ${result}=    Run Process    oscar-cli    volume    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Volume Create
    [Documentation]    Check that OSCAR CLI creates a volume
    ${result}=    Run Process    oscar-cli    volume    create    ${VOLUME_NAME}    --size    1Gi
    ...    stdout=True    stderr=True
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

*** Keywords ***
Setup Volume CLI Suite
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

Teardown Volume CLI Suite
    [Documentation]    Clean up volume and cluster
    Run Keyword And Ignore Error    Run Process    oscar-cli    volume    delete    ${VOLUME_NAME}
    ...    stdout=True    stderr=True
    Run Keyword And Ignore Error    Run Process    oscar-cli    cluster    remove    ${CLUSTER_NAME}
    ...    stdout=True    stderr=True
