*** Settings ***
Documentation       Tests for the OSCAR Manager's /system/metrics API endpoint.

Library             Collections

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/api_call.resource
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/service.resource

Suite Setup         Run Keywords    Check Valid OIDC Token    AND    Initialize Metrics Test Context
Suite Teardown      Cleanup Metrics Test Artifacts


*** Variables ***
${METRICS_RANGE_START}          2026-01-01T00:00:00Z
${METRICS_RANGE_END}            2026-01-02T00:00:00Z
${DAY_MIN_SECONDS}              82800
${DAY_MAX_SECONDS}              90000
${METRICS_TIMEOUT}              180s
${METRICS_RETRY_INTERVAL}       10s
${SERVICE_TIMEOUT}              210s
${SERVICE_RETRY_INTERVAL}       5s
${INVOCATION_SERVICE_NAME}      ${EMPTY}
${EXPOSED_SERVICE_NAME}         ${EMPTY}
${INVOCATION_SERVICE_FILE}      ${DATA_DIR}/metrics_invocation_service_file.json
${EXPOSED_SERVICE_FILE}         ${DATA_DIR}/metrics_exposed_service_file.json
${EXPOSED_SCRIPT_FILE}          ${DATA_DIR}/expose_services/nginxscript.sh


*** Test Cases ***
OSCAR System Metrics Summary
    [Documentation]    Get system metrics summary and validate the response contract.
    ${metrics}=    Fetch System Metrics
    Validate Metrics Summary Contract    ${metrics}

OSCAR System Metrics Default Range
    [Documentation]    Check that the default metrics range covers approximately the last 24 hours.
    ${metrics}=    Fetch System Metrics
    Validate Metrics Range Duration    ${metrics}    ${DAY_MIN_SECONDS}    ${DAY_MAX_SECONDS}

OSCAR System Metrics Explicit Range
    [Documentation]    Get metrics for an explicit time range and validate the echoed range.
    ${metrics}=    Fetch System Metrics    ?start=${METRICS_RANGE_START}&end=${METRICS_RANGE_END}
    Validate Metrics Summary Contract    ${metrics}
    ${start}=    Get From Dictionary    ${metrics}    start
    ${end}=    Get From Dictionary    ${metrics}    end
    Should Be Equal As Strings    ${start}    ${METRICS_RANGE_START}
    Should Be Equal As Strings    ${end}    ${METRICS_RANGE_END}
    Validate Metrics Range Duration    ${metrics}    86400    86400

OSCAR System Metrics Sync Invocation
    [Documentation]    Create a service, invoke it synchronously and verify the sync request appears in metrics.
    Ensure Invocation Service Ready
    Wait Until Keyword Succeeds
    ...    ${SERVICE_TIMEOUT}
    ...    ${SERVICE_RETRY_INTERVAL}
    ...    Invoke Sync Metrics Service
    Wait Until Keyword Succeeds
    ...    ${METRICS_TIMEOUT}
    ...    ${METRICS_RETRY_INTERVAL}
    ...    Service Metric Should Be At Least
    ...    ${INVOCATION_SERVICE_NAME}
    ...    requests-sync-per-service
    ...    1

OSCAR System Metrics Async Invocation
    [Documentation]    Invoke the test service asynchronously and verify the async request appears in metrics.
    Ensure Invocation Service Ready
    Invoke Async Metrics Service
    Wait Until Keyword Succeeds
    ...    ${METRICS_TIMEOUT}
    ...    ${METRICS_RETRY_INTERVAL}
    ...    Service Metric Should Be At Least
    ...    ${INVOCATION_SERVICE_NAME}
    ...    requests-async-per-service
    ...    1

OSCAR System Metrics Exposed Invocation
    [Documentation]    Create an exposed service, call it and verify the exposed request appears in metrics.
    Ensure Exposed Service Ready
    Invoke Exposed Metrics Service
    Wait Until Keyword Succeeds
    ...    ${METRICS_TIMEOUT}
    ...    ${METRICS_RETRY_INTERVAL}
    ...    Service Metric Should Be At Least
    ...    ${EXPOSED_SERVICE_NAME}
    ...    requests-exposed-per-service
    ...    1

OSCAR System Metrics Invalid Range
    [Documentation]    Check that /system/metrics rejects ranges where start is after end.
    ${response}=    GET With Defaults
    ...    url=${OSCAR_ENDPOINT}/system/metrics?start=${METRICS_RANGE_END}&end=${METRICS_RANGE_START}
    ...    expected_status=400
    Log    ${response.content}
    Should Contain    ${response.content}    error


*** Keywords ***
Initialize Metrics Test Context
    [Documentation]    Generate unique service names and capture the start of the metrics window.
    ${suffix}=    Evaluate    ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))    modules=random,string
    Set Suite Variable    ${RANDOM_STRING}    ${suffix}
    Set Suite Variable    ${INVOCATION_SERVICE_NAME}    metrics-invoke-${suffix}
    Set Suite Variable    ${EXPOSED_SERVICE_NAME}    metrics-exposed-${suffix}
    ${start}=    Evaluate
    ...    (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(minutes=5)).isoformat(timespec="seconds").replace("+00:00", "Z")
    ...    datetime
    Set Suite Variable    ${METRICS_TEST_START}    ${start}
    Log    Metrics test range starts at ${METRICS_TEST_START}

Ensure Invocation Service Ready
    [Documentation]    Create the sync/async test service if it is not already available.
    ${exists}=    Service Exists    ${INVOCATION_SERVICE_NAME}
    IF    not ${exists}
        Prepare Invocation Service File
        ${body}=    Get File    ${INVOCATION_SERVICE_FILE}
        ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
        Log    ${response.content}
        Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    END
    Wait Until Keyword Succeeds
    ...    ${SERVICE_TIMEOUT}
    ...    ${SERVICE_RETRY_INTERVAL}
    ...    Service Should Be Ready
    ...    ${INVOCATION_SERVICE_NAME}

Ensure Exposed Service Ready
    [Documentation]    Create the exposed test service if it is not already available.
    ${exists}=    Service Exists    ${EXPOSED_SERVICE_NAME}
    IF    not ${exists}
        Prepare Exposed Metrics Service File
        ${body}=    Get File    ${EXPOSED_SERVICE_FILE}
        ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
        Log    ${response.content}
        Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    END
    Wait Until Keyword Succeeds
    ...    ${SERVICE_TIMEOUT}
    ...    ${SERVICE_RETRY_INTERVAL}
    ...    Service Should Be Ready
    ...    ${EXPOSED_SERVICE_NAME}
    Wait Until Keyword Succeeds
    ...    ${SERVICE_TIMEOUT}
    ...    ${SERVICE_RETRY_INTERVAL}
    ...    Exposed Service Should Respond

Invoke Sync Metrics Service
    [Documentation]    Invoke the metrics test service synchronously.
    ${body}=    Get File    ${INVOKE_FILE}
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/run/${INVOCATION_SERVICE_NAME}    data=${body}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    Hello

Invoke Async Metrics Service
    [Documentation]    Invoke the metrics test service asynchronously.
    ${body}=    Get File    ${INVOKE_FILE}
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/job/${INVOCATION_SERVICE_NAME}    data=${body}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

Invoke Exposed Metrics Service
    [Documentation]    Invoke the exposed metrics test service.
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${EXPOSED_SERVICE_NAME}/exposed
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    Welcome to nginx

Service Metric Should Be At Least
    [Documentation]    Assert that a per-service metric has reached the expected value.
    [Arguments]    ${service_name}    ${metric}    ${expected_value}
    ${metric_response}=    Fetch Service Metric    ${service_name}    ${metric}
    Validate Service Metric Contract    ${metric_response}    ${service_name}    ${metric}
    ${value}=    Get From Dictionary    ${metric_response}    value
    Should Be True
    ...    ${value} >= ${expected_value}
    ...    msg=Expected ${metric} for ${service_name} to be at least ${expected_value}, got ${value}

Fetch System Metrics
    [Documentation]    Fetch /system/metrics and return the decoded JSON body.
    [Arguments]    ${query}=${EMPTY}
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/metrics${query}
    Log    ${response.content}
    ${metrics}=    Evaluate    json.loads($response.content)    json
    Should Be True    isinstance($metrics, dict)    msg=Expected /system/metrics to return a JSON object
    RETURN    ${metrics}

Fetch Service Metric
    [Documentation]    Fetch a single metric for a service within the integration test window.
    [Arguments]    ${service_name}    ${metric}
    ${end}=    Current Metrics End Timestamp
    ${response}=    GET With Defaults
    ...    url=${OSCAR_ENDPOINT}/system/metrics/${service_name}?metric=${metric}&start=${METRICS_TEST_START}&end=${end}
    Log    ${response.content}
    ${metric_response}=    Evaluate    json.loads($response.content)    json
    Should Be True    isinstance($metric_response, dict)    msg=Expected service metric response to be a JSON object
    RETURN    ${metric_response}

Current Metrics End Timestamp
    [Documentation]    Return a slightly future timestamp so delayed log timestamps remain inside the query window.
    ${end}=    Evaluate
    ...    (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=5)).isoformat(timespec="seconds").replace("+00:00", "Z")
    ...    datetime
    RETURN    ${end}

Validate Metrics Summary Contract
    [Documentation]    Validate the stable top-level contract returned by /system/metrics.
    [Arguments]    ${metrics}
    Dictionary Should Contain Key    ${metrics}    start
    Dictionary Should Contain Key    ${metrics}    end
    Dictionary Should Contain Key    ${metrics}    totals
    Dictionary Should Contain Key    ${metrics}    sources
    ${start}=    Get From Dictionary    ${metrics}    start
    ${end}=    Get From Dictionary    ${metrics}    end
    Validate RFC3339 Timestamp    ${start}
    Validate RFC3339 Timestamp    ${end}
    ${totals}=    Get From Dictionary    ${metrics}    totals
    ${sources}=    Get From Dictionary    ${metrics}    sources
    Should Be True    isinstance($totals, dict)    msg=Expected "totals" to be a JSON object
    Should Be True    isinstance($sources, list)    msg=Expected "sources" to be a JSON array
    Validate Metrics Totals    ${totals}

Validate Service Metric Contract
    [Documentation]    Validate the stable contract returned by /system/metrics/{serviceName}?metric=...
    [Arguments]    ${metric_response}    ${service_name}    ${metric}
    Dictionary Should Contain Key    ${metric_response}    service_id
    Dictionary Should Contain Key    ${metric_response}    metric
    Dictionary Should Contain Key    ${metric_response}    start
    Dictionary Should Contain Key    ${metric_response}    end
    Dictionary Should Contain Key    ${metric_response}    value
    Dictionary Should Contain Key    ${metric_response}    sources
    ${service_id}=    Get From Dictionary    ${metric_response}    service_id
    ${metric_name}=    Get From Dictionary    ${metric_response}    metric
    ${start}=    Get From Dictionary    ${metric_response}    start
    ${end}=    Get From Dictionary    ${metric_response}    end
    ${value}=    Get From Dictionary    ${metric_response}    value
    ${sources}=    Get From Dictionary    ${metric_response}    sources
    Should Be Equal As Strings    ${service_id}    ${service_name}
    Should Be Equal As Strings    ${metric_name}    ${metric}
    Validate RFC3339 Timestamp    ${start}
    Validate RFC3339 Timestamp    ${end}
    Should Be True    isinstance($value, (int, float))    msg=Expected "value" to be numeric
    Should Be True    isinstance($sources, list)    msg=Expected "sources" to be a JSON array

Validate Metrics Totals
    [Documentation]    Validate the stable numeric counters returned in the totals block.
    [Arguments]    ${totals}
    @{numeric_keys}=    Create List
    ...    services_count_active
    ...    services_count_total
    ...    cpu_hours_total
    ...    gpu_hours_total
    ...    requests_count_total
    ...    requests_count_sync
    ...    requests_count_async
    ...    requests_count_exposed
    ...    countries_count
    ...    users_count
    FOR    ${key}    IN    @{numeric_keys}
        Dictionary Should Contain Key    ${totals}    ${key}
        ${value}=    Get From Dictionary    ${totals}    ${key}
        Should Be True
        ...    isinstance($value, (int, float)) and $value >= 0
        ...    msg=Expected "${key}" to be a non-negative number
    END
    Dictionary Should Contain Key    ${totals}    countries
    Dictionary Should Contain Key    ${totals}    users
    ${countries}=    Get From Dictionary    ${totals}    countries
    ${users}=    Get From Dictionary    ${totals}    users
    Should Be True
    ...    isinstance($countries, (list, type(None)))
    ...    msg=Expected "countries" to be a JSON array or null
    Should Be True
    ...    isinstance($users, (list, type(None)))
    ...    msg=Expected "users" to be a JSON array or null

Validate Metrics Range Duration
    [Documentation]    Validate the duration between the returned start and end timestamps.
    [Arguments]    ${metrics}    ${min_seconds}    ${max_seconds}
    ${start}=    Get From Dictionary    ${metrics}    start
    ${end}=    Get From Dictionary    ${metrics}    end
    ${duration}=    Evaluate
    ...    (datetime.datetime.fromisoformat($end.replace("Z", "+00:00")) - datetime.datetime.fromisoformat($start.replace("Z", "+00:00"))).total_seconds()
    ...    datetime
    Should Be True
    ...    ${duration} >= ${min_seconds} and ${duration} <= ${max_seconds}
    ...    msg=Unexpected metrics range duration: ${duration} seconds

Validate RFC3339 Timestamp
    [Documentation]    Validate that a timestamp can be parsed as RFC3339.
    [Arguments]    ${timestamp}
    Should Not Be Empty    ${timestamp}
    Evaluate    datetime.datetime.fromisoformat($timestamp.replace("Z", "+00:00"))    datetime

Prepare Invocation Service File
    [Documentation]    Prepare a lightweight service used for sync and async invocations.
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Set Service File VO    ${service_content}
    VAR    ${modified_content}=    ${service_content}[functions][oscar][0][robot-oscar-cluster]
    ${script_value}=    Catenate
    ...    \#!/bin/sh\n\nif [ \"$INPUT_TYPE\" = \"json\" ]\nthen\n
    ...    jq '.message' \"$INPUT_FILE_PATH\" -r | /usr/games/cowsay\nelse\n
    ...    cat \"$INPUT_FILE_PATH\" | /usr/games/cowsay\nfi\n\
    Set To Dictionary    ${modified_content}    script=${script_value}
    Set To Dictionary    ${modified_content}    name=${INVOCATION_SERVICE_NAME}
    Set To Dictionary    ${modified_content}    cpu=0.5
    Set To Dictionary    ${modified_content}    memory=256Mi
    ${input_entries}=    Get From Dictionary    ${modified_content}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${INVOCATION_SERVICE_NAME}/input
    ${output_entries}=    Get From Dictionary    ${modified_content}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${INVOCATION_SERVICE_NAME}/output
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${INVOCATION_SERVICE_FILE}    ${service_content_json}

Prepare Exposed Metrics Service File
    [Documentation]    Prepare a lightweight exposed service used for exposed request metrics.
    ${service_content}=    Get File    ${DATA_DIR}/expose_services/nginx_expose.yaml
    ${service_content}=    Set Service File VO    ${service_content}
    ${script_content}=    Get File    ${EXPOSED_SCRIPT_FILE}
    ${service_content}=    Set Service File Script    ${service_content}    ${script_content}
    ${oscar_list}=    Get From Dictionary    ${service_content}[functions]    oscar
    ${first_service_item}=    Get From List    ${oscar_list}    0
    ${service_key_list}=    Get Dictionary Keys    ${first_service_item}
    ${service_key}=    Get From List    ${service_key_list}    0
    ${modified_content}=    Get From Dictionary    ${first_service_item}    ${service_key}
    Set To Dictionary    ${modified_content}    name=${EXPOSED_SERVICE_NAME}
    Set To Dictionary    ${modified_content}    cpu=0.5
    Set To Dictionary    ${modified_content}    memory=256Mi
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${EXPOSED_SERVICE_FILE}    ${service_content_json}

Service Exists
    [Documentation]    Return whether a service exists.
    [Arguments]    ${service_name}
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=ANY
    ${exists}=    Evaluate    str($response.status_code) == "200"
    RETURN    ${exists}

Service Should Be Ready
    [Documentation]    Assert that the service status indicates readiness.
    [Arguments]    ${service_name}
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=200
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${status}=    Evaluate
    ...    (lambda d: d.get("status") if not isinstance(d.get("status"), dict) else d["status"].get("state") or d["status"].get("phase") or d["status"].get("condition"))(${payload})
    ...    json
    ${ready}=    Evaluate
    ...    str(${status}).lower() in ("ready","running","available","succeeded") or bool(${payload}.get("ready")) or bool(${payload}.get("token"))
    ...    json
    Should Be True    ${ready}    Service not ready yet (status=${status})

Exposed Service Should Respond
    [Documentation]    Assert that the exposed service endpoint is reachable.
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${EXPOSED_SERVICE_NAME}/exposed
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    Welcome to nginx

Cleanup Metrics Test Artifacts
    [Documentation]    Remove services, jobs and temporary files created by this suite.
    IF    '${INVOCATION_SERVICE_NAME}' != ''
        Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${INVOCATION_SERVICE_NAME}?all=true
        Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${INVOCATION_SERVICE_NAME}
    END
    IF    '${EXPOSED_SERVICE_NAME}' != ''
        Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${EXPOSED_SERVICE_NAME}
    END
    Run Keyword And Ignore Error    Clean Test Artifacts    ${INVOCATION_SERVICE_FILE}
    Run Keyword And Ignore Error    Clean Test Artifacts    ${EXPOSED_SERVICE_FILE}
