*** Settings ***
Documentation    Tests for the OSCAR's UI dashboard.

Library          String
Library          Browser

Resource         ${CURDIR}/../resources/resources.resource

Suite Setup      Prepare Environment
Test Setup       Reload
Suite Teardown   Run Suite Teardown Tasks


*** Variables ***
${OSCAR_DASHBOARD}=        %{OSCAR_DASHBOARD}
${EGI_VO}=                 %{EGI_VO}
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

Create Service With FDL
    [Documentation]    Create a service using the FDL option
    Replace VO In Template    ${SERVICE_FILE}
    Navigate To Services Page
    Click    xpath=//button[normalize-space()='Create service']
    Click    text="FDL"
    Upload File By Selector    //input[@type='file']    ./invoke_file.yaml
    Click    xpath=//button[@role='tab' and text()='Script']
    Upload File By Selector    //input[@type='file']    ${DATA_DIR}/00-cowsay-script.sh
    Click    text="Create Service"
    Wait For Elements State    xpath=//li[contains(., 'Service robot-test-cowsay created successfully')]
    ...    visible    timeout=90s

Invoke Service
    [Documentation]    Invoke the service from inside the created service page
    Navigate To Services Page
    Filter Service By Name    robot-test-cowsay
    Click    xpath=//tbody/tr[td[text()='robot-test-cowsay']]
    Click    text="Invoke"
    Upload File By Selector    //div[@class='space-y-4 w-[800px]']//input[@type='file']    ${DATA_DIR}/${INVOKE_FILE}
    Click    text="Invoke Service"
    Wait For Elements State
    ...    xpath=//div[contains(@style, 'white-space: pre-wrap') and contains(., 'Hello there from ROBOT')]
    ...    visible    timeout=60s

Delete Service
    [Documentation]    Deletes the service created
    Navigate To Services Page
    Delete Selected Service    robot-test-cowsay

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

Filter Service By Name
    [Documentation]    Filters the services by name
    [Arguments]    ${service_name}
    Fill Text    css=input[placeholder="Filter by name"]    ${service_name}

Replace VO In Template
    [Documentation]    Replaces the VO in the template
    [Arguments]    ${TEMPLATE}
    ${invoke_file}=    Get File    ${TEMPLATE}
    ${invoke_file}=    Replace String    ${invoke_file}    <VO>    ${EGI_VO}
    Create File    ./invoke_file.yaml    ${invoke_file}

Delete Selected Service
    [Documentation]    Deletes the selected service
    [Arguments]    ${service_name}
    Filter Service By Name    ${service_name}
    Sleep    1s
    Click    xpath=//tr[td[contains(text(), '${service_name}')]]//button[@role='checkbox']
    Click    text="Delete services"
    Click    text="Delete"
    Wait For Elements State    xpath=//li[contains(., 'Services deleted successfully')]    visible    timeout=30s

Run Suite Teardown Tasks
    [Documentation]    Closes the browser and removes the files
    Close Browser
    Remove Files From Tests And Verify    True    ./invoke_file.yaml
