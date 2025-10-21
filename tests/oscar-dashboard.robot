*** Settings ***
Documentation       Tests for the OSCAR's UI dashboard.

Library             String
Library             Browser
Resource            ${CURDIR}/../resources/files.resource
Resource            ${CURDIR}/../${RESOURCE_TO_USE} 


Suite Setup         Prepare Environment
Suite Teardown      Run Suite Teardown Tasks
Test Setup          Reload


*** Variables ***
${OSCAR_DASHBOARD}      %{OSCAR_DASHBOARD}
${BROWSER}              chromium


*** Test Cases ***
Open OSCAR Dashboard Page
    [Documentation]    Checks the title of the page
    ${title}=    Get Title
    Should Contain    ${title}    OSCAR

Login to the application
    [Documentation]    Log in using the OIDC authentication
    Fill Text    xpath=//input[@name='endpoint']    ${OSCAR_ENDPOINT}
    ${token}=    Get Access Token
    VAR    ${auth_data}=    {"authenticated": "true", "token": "${token}", "endpoint": "${OSCAR_ENDPOINT}"}
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
    Should Be Equal    ${current_url}    ${OSCAR_DASHBOARD}


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

Navigate To Buckets Page
    [Documentation]    Checks the bucket page URL
    Click    div.w-full.text-sm >> "Buckets"
    ${current_url}=    Get URL
    Should Be Equal    ${current_url}    ${OSCAR_DASHBOARD}#/ui/minio

Navigate To Notebooks Page
    [Documentation]    Checks the notebook page URL
    Click    div.w-full.text-sm >> "Notebooks"
    ${current_url}=    Get URL
    Should Be Equal    ${current_url}    ${OSCAR_DASHBOARD}#/ui/notebooks

Navigate To Info Page
    [Documentation]    Checks the info page URL
    Click    div.w-full.text-sm >> "Info"
    ${current_url}=    Get URL
    Should Be Equal    ${current_url}    ${OSCAR_DASHBOARD}#/ui/info

Filter Service By Name
    [Documentation]    Filters the services by name
    [Arguments]    ${service_name}
    Fill Text    css=input[placeholder="Filter by name"]    ${service_name}

Delete Selected Service
    [Documentation]    Deletes the selected service
    [Arguments]    ${service_name}
    Filter Service By Name    ${service_name}
    Sleep    1s
    Click    xpath=//tr[td[contains(text(), '${service_name}')]]//button[@role='checkbox']
    Click    text="Delete services"
    Click    text="Delete"
    Wait For Elements State
    ...    xpath=//li[@data-type='success']//div[text()='Services deleted successfully']    visible    timeout=30s

Run Suite Teardown Tasks
    [Documentation]    Closes the browser and removes the files
    Close Browser
    Clean Test Artifacts    True    ./custom_service_file.yaml
