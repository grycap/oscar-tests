*** Settings ***
Documentation    Tests for the OSCAR's UI dashboard.

Library          String
Library          Browser

Resource         ${CURDIR}/../resources/resources.resource

Suite Setup      Prepare Environment
Test Setup       Reload
Suite Teardown   Run Suite Teardown Tasks


*** Variables ***
${OSCAR_DASHBOARD}        %{OSCAR_DASHBOARD}
${EGI_VO}                 %{EGI_VO}
${BROWSER}                chromium


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

# Create Service With FDL
#     [Documentation]    Create a service using the FDL option
#     Replace VO In Template    ${DATA_DIR}/00-cowsay.yaml
#     Navigate To Services Page
#     Click    xpath=//button[normalize-space()='Create service']
#     Click    text="FDL"
#     Upload File By Selector    //input[@type='file']    ./custom_service_file.yaml
#     Click    xpath=//button[@role='tab' and text()='Script']
#     Upload File By Selector    //input[@type='file']    ${SCRIPT_FILE}
#     Click    text="Create Service"
#     Wait For Elements State
#     ...    xpath=//li[@data-type='success']//div[text()='Service robot-test-cowsay created successfully']
#     ...    visible    timeout=120s

# Invoke Synchronous Service
#     [Documentation]    Invoke the service synchronolously from inside the created service page
#     Navigate To Services Page
#     Filter Service By Name    robot-test-cowsay
#     Sleep    1s
#     Click    xpath=//tbody/tr[td[text()='robot-test-cowsay']]
#     Click    text="Invoke"
#     Upload File By Selector    //div[@class='space-y-4 w-[800px]']//input[@type='file']    ${INVOKE_FILE}
#     Click    text="Invoke Service"
#     Wait For Elements State
#     ...    xpath=//div[contains(text(), 'Hello there from ROBOT')]    visible    timeout=120s

# Invoke Asynchronous Service
#     [Documentation]    Invoke the service asynchronously from the bucket page
#     Navigate To Buckets Page
#     Click    xpath=//tbody/tr/td/a[text()='robot-test']
#     Click    xpath=//tbody/tr/td/a[text()='input']
#     # Click    xpath=//tbody/tr/td/a[contains(., 'input')]
#     Click    text="Upload File"
#     Upload File By Selector    //input[@type='file']    ./custom_service_file.yaml
#     Click    text="Upload"
#     Wait For Elements State
#     ...    xpath=//li[@data-type='success']//div[text()='File uploaded successfully']

# Create Service With Form
#     [Documentation]    Create a service using the Form option
#     Navigate To Services Page
#     Click    text="Create service"
#     Click    text="Form"
#     Fill Text    id=service-name-input    robot-test-cowsay-form
#     Fill Text    id=docker-image-input    ghcr.io/grycap/cowsay
#     Click    id=vo-select-trigger
#     Wait For Elements State    xpath=//div[@role='option']//span[text()='vo.ai4eosc.eu']
#     ...    visible    timeout=10s
#     Click    xpath=//div[@role='option']//span[text()='vo.ai4eosc.eu']
#     Click    id=log-level-select-trigger
#     Wait For Elements State    xpath=//div[@role='option']//span[text()='CRITICAL']    visible    timeout=10s
#     Click    xpath=//div[@role='option']//span[text()='CRITICAL']
#     Click    id=script-file-input
#     Upload File By Selector    //input[@type='file']    ${SCRIPT_FILE}
#     Click    text="Create"
#     Wait For Elements State
#     ...    xpath=//li[@data-type='success']//div[text()='Service created successfully']
#     ...    visible    timeout=60s

# Check Logs
#     [Documentation]    Checks the logs of a service
#     Navigate To Services Page
#     Filter Service By Name    robot-test-cowsay
#     Click    xpath=//tr[td[normalize-space(text())='robot-test-cowsay']]
#     Click    text="Logs"
#     ${current_url}=    Get URL
#     Should Be Equal    ${current_url}    ${OSCAR_DASHBOARD}#/ui/services/robot-test-cowsay/logs
#     Click    xpath=//tr[td[starts-with(text(), 'robot-test-')]]//svg[contains(@class, 'lucide-eye')]/ancestor::button
#     Wait For Elements State    xpath=//div[@role='presentation']/div/span/span[text()='Hello there from ROBOT']
#     ...    visible    timeout=60s

# Delete Log
#     [Documentation]    Deletes the logs of a service
#     Navigate To Services Page
#     Filter Service By Name    robot-test-cowsay
#     Click    xpath=//tr[td[normalize-space(text())='robot-test-cowsay']]
#     Click    text="Logs"
#     Click    xpath=//tr[td[starts-with(text(), 'robot-test-')]]//svg[contains(@class, 'lucide-eye')]/ancestor::button
#     Click    xpath=//button[contains(text(), 'Delete selected logs')]

# Create Bucket
#     [Documentation]    Creates a bucket robot-test-cowsay
#     Navigate To Buckets Page
#     Click    text="Create bucket"
#     Fill Text    id=bucketName    robot-test-cowsay
#     Click    text="Create"

# Deploy Notebook
#     [Documentation]    Deploys the notebook in the robot-test bucket
#     Navigate To Notebooks Page
#     Click    id=bucket
#     Click    xpath=//span[text()='juno-test']
#     # xpath=//span[text()='robot-test-minio']
#     Click    id=vo
#     # Click    xpath=//button[@role='combobox'][@id='vo']
#     # Click    xpath=//div[@data-radix-select-viewport]/div[@role='option' and span[@id='radix-:r1m:'][text()='vo.ai4eosc.eu']]
#     Wait For Elements State    xpath=//div[contains(@class, 'radix')]//div[contains(., 'vo.ai4eosc.eu')]
#     ...    visible    timeout=10s
#     Click    xpath=//div[contains(@class, 'radix')]//div[contains(., 'vo.ai4eosc.eu')]
#     Click    text="Deploy"
#     Wait For Elements State    xpath=//li[@data-type='success']//div[text()='Jupyter Notebook instance deployed']
#     ...    visible    timeout=60s

# Delete Notebook
#     [Documentation]    Deletes the notebook in the robot-test bucket
#     Navigate To Notebooks Page
#     Click    text="Delete"
#     Wait For Elements State    xpath=//li[@data-type='success']//div[text()='Jupyter Notebook instance deleted']

# Delete Service
#     [Documentation]    Deletes the service created
#     Navigate To Services Page
#     Delete Selected Service    robot-test-cowsay

# Delete Form Service
#     [Documentation]    Deletes the service created
#     Navigate To Services Page
#     Delete Selected Service    robot-test-cowsay-form

# Delete Bucket
#     [Documentation]    Deletes the bucket created
#     Navigate To Buckets Page
#     Click    xpath=//tr[td//a[text()="robot-test-cowsay"]]/td//button[svg]
#     Click    text="Delete"

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

Replace VO In Template
# There is Modify Service File in the resources.resource file to do this
    [Documentation]    Replaces the VO in the template
    [Arguments]    ${TEMPLATE}
    ${invoke_file}=    Get File    ${TEMPLATE}
    ${invoke_file}=    Replace String    ${invoke_file}    <VO>    ${EGI_VO}
    Create File    ./custom_service_file.yaml    ${invoke_file}

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
    Remove Files From Tests And Verify    True    ./custom_service_file.yaml
