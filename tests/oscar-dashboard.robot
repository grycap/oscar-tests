*** Settings ***
Documentation       Tests for the OSCAR dashboard.

Library             String
Library             Browser
Resource            ${CURDIR}/../resources/files.resource
Resource            ${CURDIR}/../${AUTHENTICATION_PROCESS} 


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
    Provide Endpoint If Prompted
    ${token}=    Get Access Token
    VAR    ${auth_data}=    {"authenticated": "true", "token": "${token}", "endpoint": "${OSCAR_ENDPOINT}"}
    ${auth_data_json}=    Evaluate    json.dumps(${auth_data})    json
    LocalStorage Set Item    authData    ${auth_data_json}
    Reload
    Wait For Dashboard Route    services

Check Info
    [Documentation]    Checks the info page
    Navigate To Info Page

Log Out
    [Documentation]    Logs out the dashboard
    Navigate To Services Page
    Click    xpath=//div[span[text()='Log out']]
    ${current_url}=    Get URL
    Should Start With    ${current_url}    ${OSCAR_DASHBOARD}


*** Keywords ***
Prepare Environment
    [Documentation]    Opens the browser and navigates to the dashboard
    New Browser    ${BROWSER}    headless=True
    New Page    url= ${OSCAR_DASHBOARD}

Navigate To Services Page
    [Documentation]    Checks the services page URL
    Click    div.w-full.text-sm >> "Services"
    Wait For Dashboard Route    services

Navigate To Buckets Page
    [Documentation]    Checks the bucket page URL
    Click    div.w-full.text-sm >> "Buckets"
    Wait For Dashboard Route    minio

Navigate To Notebooks Page
    [Documentation]    Checks the notebook page URL
    Click    div.w-full.text-sm >> "Notebooks"
    Wait For Dashboard Route    notebooks

Navigate To Info Page
    [Documentation]    Checks the info page URL
    Click    div.w-full.text-sm >> "Info"
    Wait For Dashboard Route    info

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

Provide Endpoint If Prompted
    [Documentation]    Fills the dashboard endpoint if the field is displayed
    ${endpoint_locators}=    Create List    xpath=//input[@name='endpoint']    css=input[name="endpoint"]    css=input[placeholder*="endpoint"]
    FOR    ${locator}    IN    @{endpoint_locators}
        ${field_visible}=    Run Keyword And Return Status
        ...    Wait For Elements State    ${locator}    visible    timeout=5s
        IF    ${field_visible}
            Fill Text    ${locator}    ${OSCAR_ENDPOINT}
            Log    Filled endpoint field using locator: ${locator}    INFO
            RETURN
        END
    END
    Log    Endpoint field not found on login page. Continuing with token injection.    WARN

Wait For Dashboard Route
    [Documentation]    Waits until the dashboard router reaches the expected section
    [Arguments]    ${route}
    ${fragment}=    Normalize Dashboard Route    ${route}
    Wait Until Keyword Succeeds    20x    1s    Dashboard Url Should Contain Fragment    ${fragment}

Dashboard Url Should Contain Fragment
    [Documentation]    Helper assertion used to poll the current URL
    [Arguments]    ${fragment}
    ${current_url}=    Get URL
    ${current_url}=    Convert To String    ${current_url}
    ${fragment}=    Convert To String    ${fragment}
    Should Contain    ${current_url}    ${fragment}

Normalize Dashboard Route
    [Documentation]    Converts a simple route name into the hash fragment used by the dashboard
    [Arguments]    ${route}
    ${route}=    Convert To String    ${route}
    ${has_hash}=    Run Keyword And Return Status    Should Start With    ${route}    #
    IF    ${has_hash}
        RETURN    ${route}
    END
    ${starts_with_slash}=    Run Keyword And Return Status    Should Start With    ${route}    /
    IF    ${starts_with_slash}
        ${route}=    Get Substring    ${route}    1
    END
    ${fragment}=    Catenate    SEPARATOR=    #/ui/    ${route}
    RETURN    ${fragment}
