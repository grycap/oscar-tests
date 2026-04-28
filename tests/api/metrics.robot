*** Settings ***
Documentation       Tests for the OSCAR Manager's API metrics endpoints.

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS} 
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/api_call.resource
Resource            ${CURDIR}/../../resources/service.resource

Library             DateTime
Library             JSONLibrary


Suite Setup         Run Keywords    Check Valid OIDC Token    AND    Assign Random Service Name


Suite Teardown      Run Keywords    Delete Service    AND    Clean Test Artifacts    True    ${DATA_DIR}/service_file.json


*** Variables ***
${SERVICE_BASE}     robot-test-cowsay
${SERVICE_NAME}     ${SERVICE_BASE}
${DATA_DIR}             ${EXECDIR}/data
${INVOKE_FILE_NAME}     00-cowsay-invoke-body.json
${INVOKE_FILE}          ${DATA_DIR}/${INVOKE_FILE_NAME}
${SERVICE_FILE}         ${DATA_DIR}/00-cowsay.yaml



*** Test Cases ***
OSCAR Create Test Service
    [Documentation]    Create a test service for metrics tests
    ${start_date}=    Get Current Date    result_format=%Y-%m-%dT%H:%M:%SZ
    ${start_date}=      Add Time To Date    ${start_date}    -5 hours    result_format=%Y-%m-%dT%H:%M:%SZ
    Set Suite Variable    ${START_DATE}    ${start_date}
    Log    ${START_DATE}      console=yes
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    data=${body}    expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    Create Service Response: ${response.status_code}
    Log    ${response.content}
    Wait For Service Ready
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    


OSCAR Execute Service Calls
    [Documentation]    Execute service calls to generate metrics
    ${invoke_body}=    Get File    ${INVOKE_FILE}
    ${response1}=    POST    url=${OSCAR_ENDPOINT}/run/${SERVICE_NAME}    data=${invoke_body}    expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    Async Call 1 Response: ${response1.status_code}
    ${response2}=    POST    url=${OSCAR_ENDPOINT}/run/${SERVICE_NAME}    data=${invoke_body}    expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    Async Call 2 Response: ${response2.status_code}
    ${response3}=    POST    url=${OSCAR_ENDPOINT}/job/${SERVICE_NAME}    data=${invoke_body}    expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    Sync Call Response: ${response3.status_code}

OSCAR Get Metrics Summary
    [Documentation]    Get metrics summary from /system/metrics?start=${START_DATE}
    ${end_date}=    Get Current Date    result_format=%Y-%m-%dT%H:%M:%SZ
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/metrics?start=${START_DATE}&end=${end_date}    expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    ${response.status_code}
    Log    ${response.content}      console=yes
    Should Be True    ${response.status_code} in (200, 204)
    IF    ${response.status_code} == 200
        ${json}=    Convert String To Json    ${response.content}
        Should Not Be Empty    ${json}
        ${start}=    Get Value From Json    ${json}    $.start
        ${end}=    Get Value From Json    ${json}    $.end
        ${totals}=    Get Value From Json    ${json}    $.totals
        Should Not Be Empty    ${start}
        Should Not Be Empty    ${end}
        Should Not Be Empty    ${totals}
    END


OSCAR Get Metrics Breakdown
    [Documentation]    Get metrics breakdown from /system/metrics/breakdown
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/metrics/breakdown    expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    ${response.status_code}
    Log    ${response.content}
    Should Be Equal    ${response.status_code}    ${400}
    ${json}=    Convert String To Json    ${response.content}
    ${error}=    Get Value From Json    ${json}    $.error
    Should Be Equal    ${error}[0]    group_by is required

OSCAR Get Metrics Breakdown With Group By Country
    [Documentation]    Get metrics breakdown grouped by country
    ${end_date}=    Get Current Date    result_format=%Y-%m-%dT%H:%M:%SZ

    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/metrics/breakdown?&group_by=country&start=${START_DATE}&end=${end_date}    expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    ${response.status_code}
    Log    ${response.content}      console=yes
    Should Be True    ${response.status_code} in (200, 204)
    IF    ${response.status_code} == 200
        ${json}=    Convert String To Json    ${response.content}
        ${group_by}=    Get Value From Json    ${json}    $.group_by
        ${items}=    Get Value From Json    ${json}    $.items
        Should Be Equal    ${group_by}[0]    country
        Should Not Be Empty    ${items}
    END

OSCAR Get Metrics Breakdown With Group By User
    [Documentation]    Get metrics breakdown grouped by user
    ${end_date}=    Get Current Date    result_format=%Y-%m-%dT%H:%M:%SZ
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/metrics/breakdown?&group_by=user&start=${START_DATE}&end=${end_date}     expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    ${response.status_code}
    Log    ${response.content}          console=yes
    Should Be True    ${response.status_code} in (200, 204)
    IF    ${response.status_code} == 200
        ${json}=    Convert String To Json    ${response.content}
        ${group_by}=    Get Value From Json    ${json}    $.group_by
        ${items}=    Get Value From Json    ${json}    $.items
        Should Be Equal    ${group_by}[0]    user
        Should Not Be Empty    ${items}
    END


OSCAR Get Metrics Breakdown With Group By Service
    [Documentation]    Get metrics breakdown grouped by service
    ${end_date}=    Get Current Date    result_format=%Y-%m-%dT%H:%M:%SZ
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/metrics/breakdown?&group_by=service&start=${START_DATE}&end=${end_date}    expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    ${response.status_code}
    Log    ${response.content}      console=yes
    Should Be True    ${response.status_code} in (200, 204)
    IF    ${response.status_code} == 200
        ${json}=    Convert String To Json    ${response.content}
        ${group_by}=    Get Value From Json    ${json}    $.group_by
        ${items}=    Get Value From Json    ${json}    $.items
        Should Be Equal    ${group_by}[0]    service
        Should Not Be Empty    ${items}
    END


OSCAR Get Metrics Breakdown CSV Format
    [Documentation]    Get metrics breakdown in CSV format
    ${end_date}=    Get Current Date    result_format=%Y-%m-%dT%H:%M:%SZ
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/metrics/breakdown?group_by=service&format=csv   expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    ${response.status_code}
    Log    ${response.content}      console=yes
    Log    ${START_DATE}      console=yes
    Log    ${end_date}      console=yes
    Should Be True    ${response.status_code} in (200, 204)
    IF    ${response.status_code} == 200
        ${content}=    Convert To String    ${response.content}
        Should Contain    ${content}    key
        Should Contain    ${content}    ${SERVICE_NAME}
    END

OSCAR Get Service Metrics
    [Documentation]    Get metrics for a specific service
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json    
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    data=${body}    expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    Create Service Response: ${response.status_code}
    Log    ${response.content}
    Wait For Service Ready
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    ${service_response}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=200    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    Get Service Response: ${service_response.status_code}
    Log    ${service_response.content}
    ${service_json}=    Convert String To Json    ${service_response.content}
    ${service_name}=    Get Value From Json    ${service_json}    $.name
    Should Be Equal    ${service_name}    ${SERVICE_NAME}
    ${service_metrics}=    GET    url=${OSCAR_ENDPOINT}/system/metrics/${SERVICE_NAME}    expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    Service Metrics Response: ${service_metrics.status_code}
    Log    ${service_metrics.content}
    Should Be True    ${service_metrics.status_code} in (200, 204)
    IF    ${service_metrics.status_code} == 200
        ${metrics_json}=    Convert String To Json    ${service_metrics.content}
        ${metrics}=    Get Value From Json    ${metrics_json}    $.metrics
        ${metrics_len}=    Get Length    ${metrics}
        Should Be True    ${metrics_len} > 0
    END

OSCAR Get Service Metrics With Specific Metric
    [Documentation]    Get metrics for a specific service with metric parameter
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json    
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    data=${body}    expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    Create Service Response: ${response.status_code}
    Log    ${response.content}
    Wait For Service Ready
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    ${end_date}=    Add Time To Date    ${start_date}    2 days    result_format=%Y-%m-%dT%H:%M:%SZ
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/metrics/${SERVICE_NAME}?metric=cpu-hours&    expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    Specific Metric Response: ${response.status_code}
    Log    ${response.content}
    Should Be True    ${response.status_code} in (200, 204)
    IF    ${response.status_code} == 200
        ${json}=    Convert String To Json    ${response.content}
        ${metric}=    Get Value From Json    ${json}    $.metric
        ${value}=    Get Value From Json    ${json}    $.value
        ${unit}=    Get Value From Json    ${json}    $.unit
        Should Be Equal    ${metric}[0]    cpu-hours
        Should Not Be Empty    ${value}
        Should Be Equal    ${unit}[0]    hours
    END

OSCAR Get Metrics Invalid Date Range
    [Documentation]    Get metrics with invalid date range (end before start)
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/metrics?start=2026-02-02T00:00:00Z&end=2026-01-01T00:00:00Z    expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}
    Log    ${response.status_code}
    Log    ${response.content}
    Should Be Equal    ${response.status_code}    ${400}
    ${json}=    Convert String To Json    ${response.content}
    ${error}=    Get Value From Json    ${json}    $.error
    Should Be Equal    ${error}[0]    end must be after start



*** Keywords ***
Clean Test Artifacts
    [Documentation]    Removes junk files generated in the tests
    [Arguments]    @{files}
    FOR    ${file}    IN    @{files}
        Remove File    ${file}
        File Should Not Exist    ${file}
    END

Delete Service
    [Documentation]    Deletes the test service
    Run Keyword And Ignore Error    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}

Prepare Service File
    [Documentation]    Prepare the service file
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Set Service File VO    ${service_content}

    ${functions}=    Get From Dictionary    ${service_content}    functions
    ${oscar_list}=    Get From Dictionary    ${functions}    oscar
    ${first_oscar}=    Get From List    ${oscar_list}    0
    ${first_oscar_keys}=    Get Dictionary Keys    ${first_oscar}
    ${first_oscar_key}=    Get From List    ${first_oscar_keys}    0
    ${modified_content}=    Get From Dictionary    ${first_oscar}    ${first_oscar_key}

    ${script_value}=    Catenate
    ...    \#!/bin/sh\n\nif [ "$INPUT_TYPE" = "json" ]\nthen\n
    ...    jq '.message' "$INPUT_FILE_PATH" -r | /usr/games/cowsay\nelse\n
    ...    cat "$INPUT_FILE_PATH" | /usr/games/cowsay\nfi\n\
    Set To Dictionary    ${modified_content}    script=${script_value}
    Set To Dictionary    ${modified_content}    name=${SERVICE_NAME}
    ${input_entries}=    Get From Dictionary    ${modified_content}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${SERVICE_NAME}/input
    ${output_entries}=    Get From Dictionary    ${modified_content}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${SERVICE_NAME}/output
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${DATA_DIR}/service_file.json    ${service_content_json}

Wait For Service Ready
    [Documentation]    Polls the service endpoint until the service reports a ready state or the timeout expires.
    ${local_testing}=    Get Variable Value    ${LOCAL_TESTING}    ${False}
    ${timeout}=    Set Variable If    '${local_testing}'=='True'    180s    210s
    ${interval}=   Set Variable    5s
    Wait Until Keyword Succeeds    ${timeout}    ${interval}    Service Should Be Ready

Service Should Be Ready
    [Documentation]    Asserts that the service status indicates readiness.
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=200    verify=${SSL_VERIFY}    headers=${HEADERS}
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${status}=    Evaluate    (lambda d: d.get('status') if not isinstance(d.get('status'), dict) else d['status'].get('state') or d['status'].get('phase') or d['status'].get('condition'))(${payload})    json
    ${ready}=    Evaluate    str(${status}).lower() in ("ready","running","available","succeeded") or bool(${payload}.get('ready')) or bool(${payload}.get('token'))    json
    Should Be True    ${ready}    Service not ready yet (status=${status})
