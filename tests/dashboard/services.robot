*** Settings ***
Documentation       UI regression tests for the Services panel.
Resource            ${CURDIR}/../../resources/dashboard.resource

Suite Setup         Prepare Dashboard Suite
Suite Teardown      Run Dashboard Suite Teardown


*** Variables ***
${DASHBOARD_SERVICE_BASE}          dashboard-simple-test
${DASHBOARD_SERVICE_NAME}          ${EMPTY}
${DASHBOARD_SERVICE_BUCKET_NAME}   ${EMPTY}
${SIMPLE_TEST_FDL_FILE}            ${DATA_DIR}/simple-test.yaml
${SIMPLE_TEST_SCRIPT_FILE}         ${DATA_DIR}/simple-test-script.sh
${SIMPLE_TEST_INPUT_FILE}          ${DATA_DIR}/simple-test-input.payload
${DASHBOARD_SERVICE_FDL_FILE}      ${EMPTY}
${DASHBOARD_SERVICE_INPUT_FILE}    ${EMPTY}
${DASHBOARD_SERVICE_CPU}           0.5
${DASHBOARD_SERVICE_MEMORY}        64Mi
${DASHBOARD_SERVICE_BUCKETS}       1


*** Test Cases ***
Services Panel Loads By Default
    [Documentation]    Ensures the Services panel is visible after authentication.
    Wait For Dashboard Route    services

Service Filter Allows Typing
    [Documentation]    Validates that the filter field can be interacted with.
    Navigate To Services Page
    Wait For Elements State    css=input[placeholder^="Filter by"]    visible    timeout=10s
    ${query}=    Set Variable    test-service-filter
    Fill Text    css=input[placeholder^="Filter by"]    ${query}
    ${value}=    Get Attribute    css=input[placeholder^="Filter by"]    value
    Should Be Equal    ${value}    ${query}

Services Table Shows Key Columns
    [Documentation]    Checks that the Services table renders the main columns.
    Navigate To Services Page
    Wait For Elements State    xpath=//th[normalize-space()='Name']    visible    timeout=10s
    Wait For Elements State    xpath=//th[normalize-space()='Image']    visible    timeout=10s
    Wait For Elements State    xpath=//th[normalize-space()='CPU']    visible    timeout=10s
    Wait For Elements State    xpath=//th[normalize-space()='Memory']    visible    timeout=10s

Service Can Be Deployed And Invoked From Dashboard
    [Documentation]    Deploys the simple-test fixture from the Services FDL dialog and invokes it from the UI.
    [Teardown]    Cleanup Dashboard Simple Test Service
    Initialize Dashboard Simple Test Service Name
    Delete Dashboard Service Via API    ${DASHBOARD_SERVICE_NAME}
    Check Service Deployment Quota Available
    ...    ${DASHBOARD_SERVICE_CPU}
    ...    ${DASHBOARD_SERVICE_MEMORY}
    ...    ${DASHBOARD_SERVICE_BUCKETS}
    Prepare Dashboard Simple Test Files
    Create Service From Dashboard FDL
    ...    ${DASHBOARD_SERVICE_FDL_FILE}
    ...    ${SIMPLE_TEST_SCRIPT_FILE}
    ...    ${DASHBOARD_SERVICE_NAME}
    Wait For Dashboard Service Ready    ${DASHBOARD_SERVICE_NAME}
    Invoke Dashboard Service With File    ${DASHBOARD_SERVICE_NAME}    ${DASHBOARD_SERVICE_INPUT_FILE}
    Wait For Elements State
    ...    xpath=//pre[@data-robot-invoke-response='true' and contains(., 'Analysis:') and contains(., 'Words: 9')]
    ...    visible    timeout=90s
    Wait For Elements State
    ...    xpath=//pre[@data-robot-invoke-response='true' and contains(., 'Characters: 45')]
    ...    visible    timeout=10s
    Keyboard Key    press    Escape
    Delete Selected Service    ${DASHBOARD_SERVICE_NAME}
    Wait Until Keyword Succeeds    30s    2s    Dashboard Service Should Be Absent    ${DASHBOARD_SERVICE_NAME}


*** Keywords ***
Initialize Dashboard Simple Test Service Name
    [Documentation]    Creates a unique service name and matching temporary file paths for this test run.
    ${suffix}=    Evaluate    ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))    modules=random,string
    ${service_name}=    Set Variable    ${DASHBOARD_SERVICE_BASE}-${suffix}
    Set Test Variable    ${DASHBOARD_SERVICE_NAME}    ${service_name}
    Set Test Variable    ${DASHBOARD_SERVICE_BUCKET_NAME}    ${service_name}
    Set Test Variable    ${DASHBOARD_SERVICE_FDL_FILE}    ${DATA_DIR}/${service_name}.yaml
    Set Test Variable    ${DASHBOARD_SERVICE_INPUT_FILE}    ${DATA_DIR}/${service_name}-input.yaml

Prepare Dashboard Simple Test Files
    [Documentation]    Creates dashboard-specific copies of the simple-test FDL and input payload.
    ${fdl}=    Get File    ${SIMPLE_TEST_FDL_FILE}
    ${fdl}=    Replace String    ${fdl}    name: simple-test    name: ${DASHBOARD_SERVICE_NAME}
    ${fdl}=    Replace String    ${fdl}    memory: 256Mi    memory: ${DASHBOARD_SERVICE_MEMORY}
    ${fdl}=    Replace String    ${fdl}    cpu: '1.0'    cpu: '${DASHBOARD_SERVICE_CPU}'
    ${fdl}=    Replace String    ${fdl}    path: simple-test/    path: ${DASHBOARD_SERVICE_BUCKET_NAME}/
    Create File    ${DASHBOARD_SERVICE_FDL_FILE}    ${fdl}
    ${input}=    Get File    ${SIMPLE_TEST_INPUT_FILE}
    Create File    ${DASHBOARD_SERVICE_INPUT_FILE}    ${input}

Dashboard Service Should Be Absent
    [Documentation]    Asserts that the service no longer exists.
    [Arguments]    ${service_name}
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=ANY
    Should Be Equal As Strings    ${response.status_code}    404

Cleanup Dashboard Simple Test Service
    [Documentation]    Removes the dashboard simple-test service and temporary files.
    IF    '${DASHBOARD_SERVICE_NAME}' != ''
        Delete Dashboard Service Via API    ${DASHBOARD_SERVICE_NAME}
    END
    IF    '${DASHBOARD_SERVICE_FDL_FILE}' != ''
        Run Keyword And Ignore Error    Remove File    ${DASHBOARD_SERVICE_FDL_FILE}
    END
    IF    '${DASHBOARD_SERVICE_INPUT_FILE}' != ''
        Run Keyword And Ignore Error    Remove File    ${DASHBOARD_SERVICE_INPUT_FILE}
    END
