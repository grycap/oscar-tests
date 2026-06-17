*** Settings ***
Documentation       Tests for the OSCAR CLI service system-logs command (Basic Auth only).

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS} 
Resource            ${CURDIR}/../../resources/files.resource
Library             Process
Library             String

Suite Setup         Setup System Logs CLI Suite
Suite Teardown      Teardown System Logs CLI Suite

*** Variables ***
${CLUSTER_NAME}     robot-cli-syslogs
${SERVICE_NAME}     robot-cli-syslogs-svc

*** Test Cases ***
OSCAR CLI Installed
    [Documentation]    Check that OSCAR CLI is installed
    ${result}=    Run Process    oscar-cli    stdout=True    stderr=True
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI System Logs Get
    [Documentation]    Get system logs via Basic Auth
    ${result}=    Run Process    oscar-cli    service    system-logs
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI System Logs With Timestamps
    [Documentation]    Get system logs with timestamps enabled
    ${result}=    Run Process    oscar-cli    service    system-logs    --timestamps
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI System Logs JSON Output
    [Documentation]    Get system logs in JSON format
    ${result}=    Run Process    oscar-cli    service    system-logs    --output    json
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

*** Keywords ***
Setup System Logs CLI Suite
    [Documentation]    Set up admin credentials and add cluster with Basic Auth
    ${exists}=    Run Keyword And Return Status    Variable Should Exist    ${OSCAR_USER}
    IF  not ${exists}
        ${decoded}=    Evaluate    base64.b64decode('${BASIC_USER}').decode('utf-8')    modules=base64
        @{credentials}=    Split String    ${decoded}    :
        VAR    ${OSCAR_USER}=    ${credentials}[0]    scope=SUITE
        VAR    ${OSCAR_PASSWORD}=    ${credentials}[1]    scope=SUITE
        Set Global Variable    ${OSCAR_USER}
        Set Global Variable    ${OSCAR_PASSWORD}
    END
    ${result}=    Run Process    oscar-cli    cluster    add    ${CLUSTER_NAME}    ${OSCAR_ENDPOINT}
    ...    ${OSCAR_USER}    ${OSCAR_PASSWORD}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Contain    ${result.stdout}    successfully
    ${result}=    Run Process    oscar-cli    cluster    default    --set    ${CLUSTER_NAME}
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Contain    ${result.stdout}    successfully

Teardown System Logs CLI Suite
    [Documentation]    Clean up cluster configuration
    Run Keyword And Ignore Error    Run Process    oscar-cli    cluster    remove    ${CLUSTER_NAME}
    ...    stdout=True    stderr=True
