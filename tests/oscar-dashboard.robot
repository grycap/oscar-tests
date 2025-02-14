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

Create Service With FDL
    [Documentation]    Create a service using the FDL option
    Navigate To Services Page
    Click    xpath=//button[normalize-space()='Create service']
    Click    text="FDL"
    Upload File By Selector    //input[@type='file']    data/00-cowsay.yaml
    Click    xpath=//button[@role='tab' and text()='Script']
    Upload File By Selector    //input[@type='file']    data/00-cowsay-script.sh
    Click    text="Save"

# Invoke Service
#     [Documentation]    Invoke the service from inside the created service page
#     Navigate To Services Page
#     Filter Service By Name    robot-test-cowsay
#     Click    xpath=//tr[td[normalize-space(text())='robot-test-cowsay']]
#     Click    //button[normalize-space(text())='Invoke']
#     File Should Exist    ${CURDIR}/../data/00-cowsay-invoke-body.json
#     ${promise}=    Promise To Upload File    ${CURDIR}/../data/00-cowsay-invoke-body.json
#     Click  xpath=//div[contains(@class, 'border-dashed')]//button[contains(text(), 'Upload file')]
#     Wait For    ${promise}
#     Click    text="Invoke Service"

# # Create Service With Form
# #     [Documentation]    Create a service using the Form option
# #     Navigate To Services Page
# #     Click    id=radix-:r8:
# #     Click    text="Form"
# #     Fill Text    //input[@flex='1']    robot-test-cowsay-form
# #     Fill Text    //input[@flex='2']    ghcr.io/grycap/cowsay
# #     Click    xpath=//button[span[text()='CRITICAL']]
# #     # Click    text="CRITICAL"
# #     Click    id=radix-:ra1:-trigger-script
# #     Upload File By Selector    //input[@type='file']    data/00-cowsay-script.sh
# #     Click    text="Create"

# Check Logs
#     [Documentation]    Checks the logs of a service
#     Navigate To Services Page
#     Filter Service By Name    robot-test-cowsay
#     Click    xpath=//tr[td[normalize-space(text())='robot-test-cowsay']]
#     Click    text="Logs"
#     ${current_url}=    Get URL
#     Should Be Equal    ${current_url}    ${OSCAR_DASHBOARD}#/ui/services/robot-test-cowsay/logs

# Create Bucket
#     [Documentation]    Creates a bucket robot-test-cowsay
#     Navigate To Buckets Page
#     Click    text="Create bucket"
#     Fill Text    id=bucketName    robot-test-cowsay
#     Click    text="Create"

# Deploy Notebook
#     [Documentation]    Deploys the notebook in the robot-test bucket
#     Navigate To Notebooks Page
#     Click  id=bucket
#     Click  xpath=//span[text()='robot-test']
#     Click    id=vo
#     Click    xpath=//div[@role='option' and text()='vo.ai4eosc.eu']
#     Click    text="Deploy"
#     Wait For Elements State    xpath=//li[@data-sonner-toast]    Jupyter Notebook instance deployed

# Delete Notebook
#     [Documentation]    Deletes the notebook in the robot-test bucket
#     Navigate To Notebooks Page
#     # Click  id=juno-delete-button
#     Click    text="Delete"
#     Wait For Elements State    xpath=//li[@data-sonner-toast]    Jupyter Notebook instance deleted
#     # ${message}=    Get Text    xpath=//li[@data-sonner-toast]
#     # Should Contain    ${message}    Jupyter Notebook instance deployed

Delete Services
    [Documentation]    Deletes the services created previously
    Navigate To Services Page
    Delete Selected Service    robot-test-cowsay
    # Delete Selected Service    robot-test-cowsay-form

# Delete Bucket
#     [Documentation]    Deletes the bucket created previously
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
    New Browser    ${BROWSER}    headless=False
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
    Click    xpath=//tr[td[contains(normalize-space(.), "${service_name}")]]//button[svg[contains(@class, "lucide-trash2")]]
    Click    text="Delete"

Run Suite Teardown Tasks
    [Documentation]    Closes the browser and removes the files
    Close Browser
    Remove Files From Tests And Verify    True
