*** Settings ***
Documentation       Tests for the OSCAR's UI dashboard.

Library             String
Library             Browser
Resource            ${CURDIR}/../resources/resources.resource
Resource            ${CURDIR}/../resources/token.resource

Suite Setup         Prepare Environment
Suite Teardown      Run Suite Teardown Tasks
Test Setup          Reload


*** Variables ***
${OSCAR_DASHBOARD}      %{OSCAR_DASHBOARD}
${BROWSER}              chromium


*** Test Cases ***
Check Valid OIDC Token
    [Documentation]    Get the access token
    ${TOKEN}=    Get Access Token
    Check JWT Expiration    ${TOKEN}
    VAR    ${TOKEN}=    ${TOKEN}    scope=SUITE

Open OSCAR Dashboard Page
    [Documentation]    Check the title of the page
    ${title}=    Get Title
    Should Contain    ${title}    OSCAR

Login to the application
    [Documentation]    Log in using the OIDC authentication
    Fill Text    xpath=//input[@name='endpoint']    ${OSCAR_ENDPOINT}
    VAR    ${auth_data}=    {"authenticated": "true", "token": "${TOKEN}", "endpoint": "${OSCAR_ENDPOINT}"}
    ${auth_data_json}=    Evaluate    json.dumps(${auth_data})    json
    LocalStorage Set Item    authData    ${auth_data_json}
    Reload
    Wait For Navigation    ${OSCAR_DASHBOARD}#/ui/services

Create Service With FDL
    [Documentation]    Create a service using the FDL option
    Prepare Service File
    Navigate To Services Page
    Click    xpath=//button[normalize-space()='Create service']
    Click    text="FDL"
    Upload File By Selector    //input[@type='file']    ${DATA_DIR}/service_file.yaml
    Click    xpath=//button[@role='tab' and text()='Script']
    Upload File By Selector    //input[@type='file']    ${SCRIPT_FILE}
    Click    text="Create Service"
    Wait For Elements State
    ...    xpath=//li[@data-type='success']//div[text()='Service ${SERVICE_NAME} created successfully']
    ...    visible    timeout=60s

Invoke Synchronous Service
   [Documentation]    Invoke the service synchronolously from inside the created service page
   Navigate To Services Page
   Filter Service By Name    ${SERVICE_NAME}
   Sleep    2s
   Click    xpath=//tbody/tr[td[text()='${SERVICE_NAME}']]
   Click    text="Invoke"
   Upload File By Selector    //input[@type='file' and @accept='image/*,.json,.yaml,.yml']    ${INVOKE_FILE}
   Sleep    2s
   Click    text="Invoke Service"
   Wait For Elements State
   ...    xpath=//div[contains(text(), 'Hello there from ROBOT')]    visible    timeout=60s

Invoke Asynchronous Service
   [Documentation]    Invoke the service asynchronously from the bucket page
   Navigate To Buckets Page
   Click    xpath=//tbody/tr/td/a[text()='${BUCKET_NAME}']
   Click    xpath=//tbody/tr/td/a[text()='input']
   Click    text="Upload File"
   Upload File By Selector    //input[@type='file']    ${INVOKE_FILE}
   Click    text="Upload"
   Wait For Elements State
   ...    xpath=//li[@data-type='success']//div[text()='File uploaded successfully']

Check Logs
    [Documentation]    Check the logs of a service
    Navigate To Services Page
    Filter Service By Name    ${SERVICE_NAME}
    Click    xpath=//tr[td[normalize-space(text())='${SERVICE_NAME}']]
    Click    text="Logs"
    Sleep    20s
    Reload
    ${current_url}=    Get URL
    Should Be Equal    ${current_url}    ${OSCAR_DASHBOARD}#/ui/services/${SERVICE_NAME}/logs
    Click    css=button:has(svg.lucide-eye)
    Wait For Elements State    xpath=//span[contains(text(), "ROBOT")]    visible    timeout=60s

Delete Log
    [Documentation]    Delete the logs of a service
    Navigate To Services Page
    Filter Service By Name    ${SERVICE_NAME}
    Click    xpath=//tr[td[normalize-space(text())='${SERVICE_NAME}']]
    Click    text="Logs"
    Reload
    Sleep    10s
    Click    css=tr:has-text("${SERVICE_NAME}") >> css=button:has(svg.lucide-trash2)
    Click    xpath=//button[.//div[text()='Delete']]
    Wait For Elements State
    ...    xpath=//li[@data-type='success']//div[contains(text(), 'was deleted successfully')]
    ...    visible    timeout=60s

Delete Services
   [Documentation]    Delete the services created previously
   Navigate To Services Page
   Delete Selected Service    ${SERVICE_NAME}

Check Info
    [Documentation]    Check the info page
    Navigate To Info Page

Log Out
    [Documentation]    Log out the dashboard
    Navigate To Services Page
    Click    xpath=//div[span[text()='Log out']]
    ${current_url}=    Get URL
    Should Be Equal    ${current_url}    ${OSCAR_DASHBOARD}#/login


*** Keywords ***
Prepare Environment
    [Documentation]    Open the browser and navigates to the dashboard
    New Browser    ${BROWSER}    headless=True
    New Page    url= ${OSCAR_DASHBOARD}

Navigate To Services Page
    [Documentation]    Check the services page URL
    Click    div.w-full.text-sm >> "Services"
    ${current_url}=    Get URL
    Should Be Equal    ${current_url}    ${OSCAR_DASHBOARD}#/ui/services

Navigate To Buckets Page
    [Documentation]    Check the bucket page URL
    Click    div.w-full.text-sm >> "Buckets"
    ${current_url}=    Get URL
    Should Be Equal    ${current_url}    ${OSCAR_DASHBOARD}#/ui/minio

Navigate To Info Page
    [Documentation]    Check the info page URL
    Click    div.w-full.text-sm >> "Info"
    ${current_url}=    Get URL
    Should Be Equal    ${current_url}    ${OSCAR_DASHBOARD}#/ui/info

Filter Service By Name
    [Documentation]    Filter the services by name
    [Arguments]    ${service_name}
    Fill Text    css=input[placeholder="Filter by name"]    ${service_name}

Delete Selected Service
    [Documentation]    Delete the selected service
    [Arguments]    ${service_name}
    Filter Service By Name    ${service_name}
    Sleep    1s
    Click    xpath=//tr[td[contains(text(), '${service_name}')]]//button[@role='checkbox']
    Click    text="Delete services"
    Click    text="Delete"
    Wait For Elements State
    ...    xpath=//li[@data-type='success']//div[text()='Services deleted successfully']    visible    timeout=30s

Prepare Service File
    [Documentation]    Prepare the service file for service creation
    ${service_content}=    Load Original Service File    ${SERVICE_FILE}
    ${service_content}=    Set Service File VO    ${service_content}
    Save YAML File    ${service_content}    ${DATA_DIR}/service_file.yaml

Run Suite Teardown Tasks
    [Documentation]    Close the browser and remove the files
    Close Browser
    Clean Test Artifacts    True    ${DATA_DIR}/service_file.yaml
