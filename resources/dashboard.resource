*** Settings ***
Documentation       Shared keywords and resources for OSCAR dashboard panel tests.
Library             String
Library             Browser
Resource            ${CURDIR}/files.resource
Resource            ${CURDIR}/../${AUTHENTICATION_PROCESS}


*** Variables ***
${OSCAR_DASHBOARD}      %{OSCAR_DASHBOARD}
${BROWSER}              chromium


*** Keywords ***
Prepare Dashboard Suite
    [Documentation]    Launches the browser, opens the dashboard and authenticates the session.
    Open Dashboard Browser
    Open Dashboard Page
    Authenticate To Dashboard

Run Dashboard Suite Teardown
    [Documentation]    Closes the browser and removes temporary files.
    Close Browser
    Clean Test Artifacts    True    ./custom_service_file.yaml

Open Dashboard Browser
    [Documentation]    Starts a new headless browser instance.
    New Browser    ${BROWSER}    headless=True

Open Dashboard Page
    [Documentation]    Navigates to the dashboard landing page.
    New Page    url=${OSCAR_DASHBOARD}

Authenticate To Dashboard
    [Documentation]    Injects the OIDC token in local storage and waits for services to load.
    Provide Endpoint If Prompted
    ${token}=    Get Access Token
    VAR    ${auth_data}=    {"authenticated": "true", "token": "${token}", "endpoint": "${OSCAR_ENDPOINT}"}
    ${auth_data_json}=    Evaluate    json.dumps(${auth_data})    json
    LocalStorage Set Item    authData    ${auth_data_json}
    Reload
    Wait For Dashboard Route    services

Navigate To Services Page
    [Documentation]    Opens the Services panel and waits for it to render.
    ${target}=    Normalize Dashboard Route    services
    ${current_url}=    Get URL
    ${current_url}=    Convert To String    ${current_url}
    ${already_there}=    Run Keyword And Return Status    Should Contain    ${current_url}    ${target}
    IF    not ${already_there}
        Click    css=a[data-sidebar="menu-button"][href="#/ui/services"]
    END
    Wait For Dashboard Route    services

Navigate To Buckets Page
    [Documentation]    Opens the Buckets (MinIO) panel and waits for it to render.
    ${target}=    Normalize Dashboard Route    minio
    ${current_url}=    Get URL
    ${current_url}=    Convert To String    ${current_url}
    ${already_there}=    Run Keyword And Return Status    Should Contain    ${current_url}    ${target}
    IF    not ${already_there}
        Click    css=a[data-sidebar="menu-button"][href="#/ui/minio"]
    END
    Wait For Dashboard Route    minio

Navigate To Notebooks Page
    [Documentation]    Opens the Notebooks panel and waits for it to render.
    ${target}=    Normalize Dashboard Route    notebooks
    ${current_url}=    Get URL
    ${current_url}=    Convert To String    ${current_url}
    ${already_there}=    Run Keyword And Return Status    Should Contain    ${current_url}    ${target}
    IF    not ${already_there}
        Click    css=a[data-sidebar="menu-button"][href="#/ui/notebooks"]
    END
    Wait For Dashboard Route    notebooks

Navigate To Info Page
    [Documentation]    Opens the Info panel and waits for it to render.
    ${target}=    Normalize Dashboard Route    info
    ${current_url}=    Get URL
    ${current_url}=    Convert To String    ${current_url}
    ${already_there}=    Run Keyword And Return Status    Should Contain    ${current_url}    ${target}
    IF    not ${already_there}
        Click    css=a[data-sidebar="menu-button"][href="#/ui/info"]
    END
    Wait For Dashboard Route    info

Filter Service By Name
    [Documentation]    Filters services by the provided name.
    [Arguments]    ${service_name}
    Fill Text    css=input[placeholder^="Filter by"]    ${service_name}

Delete Selected Service
    [Documentation]    Removes a service by name from the Services panel.
    [Arguments]    ${service_name}
    Filter Service By Name    ${service_name}
    Sleep    1s
    Click    xpath=//tr[td[contains(text(), '${service_name}')]]//button[@role='checkbox']
    Click    text="Delete services"
    Click    text="Delete"
    Wait For Elements State
    ...    xpath=//li[@data-type='success']//div[text()='Services deleted successfully']    visible    timeout=30s

Provide Endpoint If Prompted
    [Documentation]    Fills the OSCAR endpoint field when rendered by the UI.
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
    [Documentation]    Waits until the router transitions to the expected hash fragment.
    [Arguments]    ${route}
    ${fragment}=    Normalize Dashboard Route    ${route}
    Wait Until Keyword Succeeds    20x    1s    Dashboard Url Should Contain Fragment    ${fragment}

Dashboard Url Should Contain Fragment
    [Documentation]    Polls the current URL until it contains the expected fragment.
    [Arguments]    ${fragment}
    ${current_url}=    Get URL
    ${current_url}=    Convert To String    ${current_url}
    ${fragment}=    Convert To String    ${fragment}
    Should Contain    ${current_url}    ${fragment}

Normalize Dashboard Route
    [Documentation]    Converts a route name into the router hash fragment.
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
    ${fragment}=    Catenate    SEPARATOR=    \#/ui/    ${route}
    RETURN    ${fragment}
