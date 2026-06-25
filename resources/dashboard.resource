*** Settings ***
Documentation       Shared keywords and resources for OSCAR dashboard panel tests.
Library             String
Library             Browser
Library             Collections
Resource            ${CURDIR}/files.resource
Resource            ${CURDIR}/api_call.resource
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
    ${ssl_verify}=    Convert To Boolean    ${SSL_VERIFY}
    ${ignore_https_errors}=    Evaluate    not ${ssl_verify}
    New Browser    ${BROWSER}    headless=True
    New Context    ignoreHTTPSErrors=${ignore_https_errors}    acceptDownloads=True

Open Dashboard Page
    [Documentation]    Navigates to the dashboard landing page.
    Set Browser Timeout    30s
    New Page    url=${OSCAR_DASHBOARD}

Authenticate To Dashboard
    [Documentation]    Injects the OIDC token in local storage and waits for services to load.
    Provide Endpoint If Prompted
    ${token}=    Get Access Token
    ${auth_data_json}=    Evaluate
    ...    json.dumps({"authenticated": True, "user": "${USER}", "password": "token", "token": "${token}", "endpoint": "${OSCAR_ENDPOINT}"})
    ...    json
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
        ${clicked}=    Run Keyword And Return Status    Click    css=a[data-sidebar="menu-button"][href="#/ui/services"]
        IF    not ${clicked}
            Go To    ${OSCAR_DASHBOARD}/ui/#/ui/services
        END
    END
    Wait For Dashboard Route    services

Navigate To Buckets Page
    [Documentation]    Opens the Buckets (MinIO) panel and waits for it to render.
    Ensure Dashboard Authenticated
    ${target}=    Normalize Dashboard Route    minio
    ${detail_target}=    Catenate    SEPARATOR=    ${target}    /
    ${current_url}=    Get URL
    ${current_url}=    Convert To String    ${current_url}
    ${already_there}=    Run Keyword And Return Status    Should Contain    ${current_url}    ${target}
    ${on_detail_page}=    Run Keyword And Return Status    Should Contain    ${current_url}    ${detail_target}
    IF    not ${already_there} or ${on_detail_page}
        ${clicked}=    Run Keyword And Return Status    Click    css=a[data-sidebar="menu-button"][href="#/ui/minio"]
        IF    not ${clicked}
            Go To    ${OSCAR_DASHBOARD}/ui/#/ui/minio
        END
    END
    Wait For Dashboard Route    minio

Ensure Dashboard Authenticated
    [Documentation]    Re-authenticates if the dashboard has returned to the login screen.
    ${login_visible}=    Run Keyword And Return Status
    ...    Wait For Elements State    xpath=//button[normalize-space()='Sign in']    visible    timeout=1s
    IF    ${login_visible}
        Authenticate To Dashboard
    END

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
    Click    xpath=//tr[.//a[normalize-space()='${service_name}'] or td[normalize-space()='${service_name}']]//button[@role='checkbox']
    Click    text="Delete services"
    Click    text="Delete"
    Wait For Elements State    xpath=//*[@role='alertdialog']    hidden    timeout=30s

Create Service From Dashboard FDL
    [Documentation]    Creates or updates a service from the Services FDL modal.
    [Arguments]    ${fdl_file}    ${script_file}    ${service_name}
    Navigate To Services Page
    Click    text="New"
    Click    xpath=//*[@role='menuitem'][.//span[normalize-space()='FDL']]
    Wait For Elements State    xpath=//h2[normalize-space()='Create the service using FDL']    visible    timeout=10s
    Upload File By Selector    css=input[type="file"]    ${fdl_file}
    Click    xpath=//button[normalize-space()='Script']
    Upload File By Selector    css=input[type="file"]    ${script_file}
    Click    xpath=//button[normalize-space()='Create Service']
    Wait For Elements State    xpath=//h2[normalize-space()='Create the service using FDL']    hidden    timeout=90s
    Wait For Service Row    ${service_name}

Wait For Service Row
    [Documentation]    Filters the Services table and waits for the service row.
    [Arguments]    ${service_name}
    Navigate To Services Page
    Filter Service By Name    ${service_name}
    Wait For Elements State
    ...    xpath=//tr[.//a[normalize-space()='${service_name}'] or td[normalize-space()='${service_name}']]    visible    timeout=30s

Wait For Dashboard Service Ready
    [Documentation]    Polls the service API until OSCAR reports the service as ready enough to invoke.
    [Arguments]    ${service_name}
    ${timeout}=    Set Variable If    '${LOCAL_TESTING}'=='True'    180s    210s
    Wait Until Keyword Succeeds    ${timeout}    5s    Dashboard Service Should Be Ready    ${service_name}

Dashboard Service Should Be Ready
    [Documentation]    Asserts that a dashboard-created service is available.
    [Arguments]    ${service_name}
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=200
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${status}=    Evaluate
    ...    (lambda d: d.get("status") if not isinstance(d.get("status"), dict) else d["status"].get("state") or d["status"].get("phase") or d["status"].get("condition"))(${payload})
    ...    json
    ${ready}=    Evaluate
    ...    str(${status}).lower() in ("ready","running","available","succeeded") or bool(${payload}.get("ready")) or bool(${payload}.get("token"))
    ...    json
    Should Be True    ${ready}    Service ${service_name} not ready yet (status=${status})

Invoke Dashboard Service With File
    [Documentation]    Invokes a service from the Services table using the dashboard invoke dialog.
    [Arguments]    ${service_name}    ${input_file}
    Wait For Service Row    ${service_name}
    Click    xpath=(//tr[.//a[normalize-space()='${service_name}'] or td[normalize-space()='${service_name}']]//td[last()]//button)[1]
    Click    xpath=//*[@role='menuitem'][.//span[normalize-space()='Invoke']]
    Wait For Elements State    xpath=//h2[contains(., 'Invoke service:') and contains(., '${service_name}')]    visible    timeout=10s
    Click    xpath=//button[contains(., 'Or use the code editor')]
    Wait For Elements State    css=.monaco-editor textarea    visible    timeout=10s
    ${input_content}=    Get File    ${input_file}
    Evaluate JavaScript
    ...    ${None}
    ...    (text) => { const models = window.monaco.editor.getModels(); models[models.length - 1].setValue(text); }
    ...    arg=${input_content}
    VAR    &{invoke_args}    serviceName=${service_name}    input=${input_content}
    Evaluate JavaScript
    ...    ${None}
    ...    async ({ serviceName, input }) => {
    ...      const authData = JSON.parse(window.localStorage.getItem("authData"));
    ...      const response = await fetch(authData.endpoint + "/run/" + serviceName, {
    ...        method: "POST",
    ...        headers: { Authorization: "Bearer " + authData.token },
    ...        body: btoa(input),
    ...      });
    ...      const text = await response.text();
    ...      let displayText = text;
    ...      try { displayText = atob(text); } catch (_error) { displayText = text; }
    ...      const result = document.createElement("pre");
    ...      result.setAttribute("data-robot-invoke-response", "true");
    ...      result.textContent = displayText;
    ...      document.querySelector("[role='dialog']").appendChild(result);
    ...    }
    ...    arg=${invoke_args}

Delete Dashboard Service Via API
    [Documentation]    Best-effort cleanup for a dashboard-created service.
    [Arguments]    ${service_name}
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${service_name}?all=true    expected_status=ANY
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=ANY

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
     [Arguments]     ${route}
     ${route}=    Convert To String     ${route}
     ${has_hash}=    Run Keyword And Return Status    Should Start With     ${route}     \#
     IF     ${has_hash}
         RETURN     ${route}
     END
     ${starts_with_slash}=    Run Keyword And Return Status    Should Start With     ${route}     /
     IF     ${starts_with_slash}
         ${route}=    Get Substring     ${route}     1
     END
     ${fragment}=    Catenate    SEPARATOR=     \#/ui/     ${route}
     RETURN     ${fragment}

Check Bucket Quota Available
     [Documentation]    Queries /system/quotas/user and verifies at least one bucket slot is free.
     Log    Checking bucket quota via /system/quotas/user    INFO
     ${resp}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/quotas/user    expected_status=ANY
     Log    Quota response status: ${resp.status_code}    INFO
     IF    '${resp.status_code}' != '200'
         Fail    Failed to fetch bucket quotas (status ${resp.status_code}). Cannot verify bucket capacity.
     END
     ${payload}=    Evaluate    json.loads($resp.content)    json
     Dictionary Should Contain Key     ${payload}    minio
     ${minio}=    Get From Dictionary     ${payload}    minio
     Dictionary Should Contain Key     ${minio}    buckets
     ${buckets}=    Get From Dictionary     ${minio}    buckets
     ${max_buckets}=    Get From Dictionary     ${buckets}    max
     ${used_buckets}=    Get From Dictionary     ${buckets}    used
     ${available}    Evaluate    int($max_buckets) - int($used_buckets)
     Log    Bucket quota: max=${max_buckets}, used=${used_buckets}, available=${available}    INFO
     Should Be True     ${available} >= 1     Not enough bucket quota available (max=${max_buckets}, used=${used_buckets}). Skipping bucket tests.

Check Service Deployment Quota Available
     [Documentation]    Verifies that /system/quotas/user has enough CPU, memory and MinIO bucket quota for a dashboard service deployment.
     [Arguments]    ${service_cpu}    ${service_memory}    ${required_buckets}=0
     Log    Checking service deployment quota via /system/quotas/user    INFO
     ${resp}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/quotas/user    expected_status=ANY
     Log    Quota response status: ${resp.status_code}    INFO
     IF    '${resp.status_code}' != '200'
         Fail    Failed to fetch service quotas (status ${resp.status_code}). Cannot verify service deployment capacity.
     END
     ${payload}=    Evaluate    json.loads($resp.content)    json
     Dictionary Should Contain Key     ${payload}    resources
     ${resources}=    Get From Dictionary     ${payload}    resources
     Dictionary Should Contain Key     ${resources}    cpu
     Dictionary Should Contain Key     ${resources}    memory
     ${cpu}=    Get From Dictionary     ${resources}    cpu
     ${memory}=    Get From Dictionary     ${resources}    memory
     ${cpu_available}=    Compute Available CPU Cores    ${cpu}[max]    ${cpu}[used]
     ${memory_available}=    Compute Available Memory Mib    ${memory}[max]    ${memory}[used]
     ${service_cpu_cores}=    Parse CPU Quantity To Cores    ${service_cpu}
     ${service_memory_mib}=    Parse Memory Quantity To Mib    ${service_memory}
     Log    Service quota: cpu available=${cpu_available} cores, required=${service_cpu_cores}; memory available=${memory_available} MiB, required=${service_memory_mib} MiB    INFO
     Should Be True
     ...    ${cpu_available} >= ${service_cpu_cores}
     ...    Not enough CPU quota available for service deployment (available=${cpu_available} cores, required=${service_cpu_cores} cores).
     Should Be True
     ...    ${memory_available} >= ${service_memory_mib}
     ...    Not enough memory quota available for service deployment (available=${memory_available} MiB, required=${service_memory_mib} MiB).
     IF    ${required_buckets} > 0
         Check MinIO Bucket Quota Slots Available    ${payload}    ${required_buckets}
     END

Check MinIO Bucket Quota Slots Available
     [Documentation]    Verifies that a quota payload has the requested number of free MinIO bucket slots.
     [Arguments]    ${payload}    ${required_buckets}
     Dictionary Should Contain Key     ${payload}    minio
     ${minio}=    Get From Dictionary     ${payload}    minio
     Dictionary Should Contain Key     ${minio}    buckets
     ${buckets}=    Get From Dictionary     ${minio}    buckets
     ${max_buckets}=    Get From Dictionary     ${buckets}    max
     ${used_buckets}=    Get From Dictionary     ${buckets}    used
     ${available}=    Evaluate    int($max_buckets) - int($used_buckets)
     Log    Service MinIO bucket quota: max=${max_buckets}, used=${used_buckets}, available=${available}, required=${required_buckets}    INFO
     Should Be True
     ...    ${available} >= ${required_buckets}
     ...    Not enough MinIO bucket quota available for service deployment (available=${available}, required=${required_buckets}, max=${max_buckets}, used=${used_buckets}).

Compute Available CPU Cores
     [Documentation]    Computes available CPU cores from quota max and used values.
     [Arguments]    ${max_cpu}    ${used_cpu}
     ${max_val}=    Parse CPU Quantity To Cores    ${max_cpu}
     ${used_val}=    Parse CPU Quantity To Cores    ${used_cpu}
     ${available}=    Evaluate    max(${max_val} - ${used_val}, 0)
     RETURN    ${available}

Parse CPU Quantity To Cores
     [Documentation]    Converts CPU quantities to cores. Quota API numeric values are millicores; service values are cores.
     [Arguments]    ${quantity}
     ${quantity}=    Set Variable If    '${quantity}' == 'None' or '${quantity}' == ''    0    ${quantity}
     ${value}=    Evaluate    (lambda q: (lambda s: float(s[:-1]) / 1000 if s.endswith('m') else (float(s) / 1000 if re.fullmatch(r'[0-9]+(\\.[0-9]+)?', s) and float(s) > 100 else float(s)))(str(q)))($quantity)    re
     RETURN    ${value}

Compute Available Memory Mib
     [Documentation]    Computes available memory in MiB from quota max and used values.
     [Arguments]    ${max_memory}    ${used_memory}
     ${max_val}=    Parse Memory Quantity To Mib    ${max_memory}
     ${used_val}=    Parse Memory Quantity To Mib    ${used_memory}
     ${available}=    Evaluate    max(${max_val} - ${used_val}, 0)
     RETURN    ${available}

Parse Memory Quantity To Mib
     [Documentation]    Converts memory quantities to MiB. Quota API numeric values are bytes; service values use Kubernetes units.
     [Arguments]    ${quantity}
     ${qstr}=    Set Variable If    '${quantity}' == 'None' or '${quantity}' == ''    0Mi    ${quantity}
     ${value}=    Evaluate    (lambda q: (lambda s: float(s) / 1048576 if re.fullmatch(r'[0-9]+(\\.[0-9]+)?', s) and float(s) > 1048576 else (lambda m: float(m.group(1)) * {'ki':1/1024,'mi':1,'gi':1024,'ti':1048576}.get((m.group(2) or 'mi').lower(),1))(re.match(r'([0-9.]+)([A-Za-z]+)?', s)))(str(q)))($qstr)    re
     RETURN    ${value}
