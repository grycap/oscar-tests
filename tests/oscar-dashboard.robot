*** Settings ***
Documentation    Tests for the OSCAR's UI dashboard.

Library          Browser

Resource         ${CURDIR}/../resources/resources.resource

Suite Setup      Prepare Environment
Test Setup       Reload
Suite Teardown   Run Suite Teardown Tasks


*** Variables ***
${OSCAR_DASHBOARD}=        %{OSCAR_DASHBOARD}
${BROWSER}=                chromium


*** Test Cases ***
Check Valid OIDC Token
    [Documentation]    Get the access token
    ${TOKEN}=    Get Access Token
    Check JWT Expiration    ${TOKEN}
    VAR    ${TOKEN}    ${TOKEN}    scope=SUITE

Open OSCAR Dashboard Page
    [Documentation]    Checks the title of the page
    ${title}=    Get Title
    Should Contain    ${title}    OSCAR

Login to the application
    [Documentation]    Log in using the OIDC authentication
    Fill Text    xpath=//input[@name='endpoint']    ${OSCAR_ENDPOINT}
    VAR    ${auth_data}    {"authenticated": "true", "token": "${TOKEN}", "endpoint": "${OSCAR_ENDPOINT}"}
    ${auth_data_json}=    Evaluate    json.dumps(${auth_data})    json
    LocalStorage Set Item    authData    ${auth_data_json}
    Reload
    Wait For Navigation    ${OSCAR_DASHBOARD}#/ui/services

Check Info
    [Documentation]    Checks the info page
    Navigate To Info Page

Log Out
    [Documentation]    Logs out the dashboard
    Navigate To Services Page
    Click    xpath=//div[span[text()='Log out']]
    ${current_url}=    Get URL
    Should Be Equal    ${current_url}    ${OSCAR_DASHBOARD}#/login


*** Keywords ***
Prepare Environment
    [Documentation]    Opens the browser and navigates to the dashboard
    New Browser    ${BROWSER}    headless=True
    New Page    url= ${OSCAR_DASHBOARD}

Navigate To Services Page
    [Documentation]    Checks the services page URL
    Click    div.w-full.text-sm >> "Services"
    ${current_url}=    Get URL
    Should Be Equal    ${current_url}    ${OSCAR_DASHBOARD}#/ui/services

Navigate To Info Page
    [Documentation]    Checks the info page URL
    Click    div.w-full.text-sm >> "Info"
    ${current_url}=    Get URL
    Should Be Equal    ${current_url}    ${OSCAR_DASHBOARD}#/ui/info

Run Suite Teardown Tasks
    [Documentation]    Closes the browser and removes the files
    Close Browser
    Remove Files From Tests And Verify    True
