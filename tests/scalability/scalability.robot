*** Settings ***
Documentation       Scalability tests for OSCAR service invocations executed through Locust.

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/service.resource
Library             Collections
Library             OperatingSystem
Library             Process
Library             RequestsLibrary
Library             String

Suite Setup         Setup Scalability Environment
Suite Teardown      Teardown Scalability Environment


*** Variables ***
${SCALABILITY_SRC_DIR}              ${CURDIR}/src
${LOCUSTFILE}                       ${SCALABILITY_SRC_DIR}/oscar_invocations.py
${COLLECTOR}                        ${SCALABILITY_SRC_DIR}/collect_scalability_results.py
${LOAD_PLANNER}                     ${SCALABILITY_SRC_DIR}/plan_scalability_load.py
${CLUSTER_STATUS_CAPTURE}           ${SCALABILITY_SRC_DIR}/capture_cluster_status.py
${BASELINE_MEASURER}                ${SCALABILITY_SRC_DIR}/measure_baseline_invocations.py
${ASYNC_WARMUP}                     ${SCALABILITY_SRC_DIR}/warm_async_invocations.py
${RUN_CONFIG_WRITER}                ${SCALABILITY_SRC_DIR}/write_run_configuration.py
${EXPERIMENT_BUILDER}               ${SCALABILITY_SRC_DIR}/build_experiment.py
${SCALABILITY_VIEWER_DIR}           ${CURDIR}/viewer
${SCALABILITY_SERVICE_FILE}         ${DATA_DIR}/simple-test.yaml
${SCALABILITY_SERVICE_SCRIPT}       ${DATA_DIR}/simple-test-script.sh
${SCALABILITY_SERVICE_JSON}         ${DATA_DIR}/simple-test-scalability.json
${SCALABILITY_SERVICE_BASE}         simple-test
${SCALABILITY_SERVICE_NAME}         ${SCALABILITY_SERVICE_BASE}
${SCALABILITY_PAYLOAD_FILE}         ${DATA_DIR}/simple-test-input.payload
${SCALABILITY_OUTPUT_DIR}           ${EXECDIR}/robot_results/scalability
${SCALABILITY_EXPERIMENTS_DIR}      ${SCALABILITY_OUTPUT_DIR}/experiments
${SCALABILITY_EXPERIMENT_DIR}       ${EMPTY}
${SCALABILITY_USERS}                1,2,4
${SCALABILITY_SPAWN_RATE}           1
${SCALABILITY_RUN_TIME}             30s
${SCALABILITY_ASYNC_SETTLE_TIME}    60s
${SCALABILITY_ASYNC_WAIT_MIN}       1
${SCALABILITY_ASYNC_WAIT_MAX}       1
${SCALABILITY_SERVICE_CPU}          1.0
${SCALABILITY_SERVICE_MEMORY}       265Mi
${SCALABILITY_USE_QUOTAS}           ${True}
${SCALABILITY_QUOTA_MODE}           exploratory
${SCALABILITY_EFFECTIVE_USERS}      ${SCALABILITY_USERS}
${SCALABILITY_CLUSTER_RESOURCES}    ${None}
${SCALABILITY_AUTH_MODE}            user
${SCALABILITY_AUTH_HEADER}          ${EMPTY}
${SCALABILITY_INVOCATION_AUTH_HEADER}       ${EMPTY}
${SCALABILITY_INVOCATION_AUTH_SOURCE}       ${EMPTY}
${SCALABILITY_SYNC_ENABLED}         ${True}
${SCALABILITY_ASYNC_ENABLED}        ${True}
${SCALABILITY_BASELINE_ENABLED}     ${True}
${SCALABILITY_BASELINE_SYNC_RETRIES}        15
${SCALABILITY_BASELINE_SYNC_RETRY_INTERVAL}     2
${SCALABILITY_BASELINE_ASYNC_TIMEOUT}       120
${SCALABILITY_BASELINE_ASYNC_POLL_INTERVAL}     2
${SCALABILITY_ASYNC_WARMUP_ENABLED}     ${True}
${SCALABILITY_ASYNC_WARMUP_JOBS}        3
${SCALABILITY_ASYNC_WARMUP_SUBMIT_INTERVAL}     1
${SCALABILITY_CLEAN_JOBS}           ${True}
${SCALABILITY_CLEAN_SERVICE}        ${True}
${LOCUST_WAIT_MIN}                  0
${LOCUST_WAIT_MAX}                  0


*** Test Cases ***
OSCAR Sync Invocation Scalability
    [Documentation]    Measure synchronous service invocation through POST /run/{service}.
    [Tags]    scalability    sync
    Skip If    not ${SCALABILITY_SYNC_ENABLED}
    Run Scalability Steps    sync

OSCAR Async Invocation Scalability
    [Documentation]    Measure asynchronous job submission through POST /job/{service} and collect job states afterwards.
    [Tags]    scalability    async
    Skip If    not ${SCALABILITY_ASYNC_ENABLED}
    Run Scalability Steps    async


*** Keywords ***
Setup Scalability Environment
    [Documentation]    Create a simple-test based service and export environment variables consumed by Locust.
    ${service_name}=    Generate Random Service Name    ${SCALABILITY_SERVICE_BASE}
    Set Suite Variable    ${SCALABILITY_SERVICE_NAME}    ${service_name}
    Create Directory    ${SCALABILITY_OUTPUT_DIR}
    Create Directory    ${SCALABILITY_EXPERIMENTS_DIR}
    ${experiment_dir}=    Catenate    SEPARATOR=/    ${SCALABILITY_EXPERIMENTS_DIR}    ${SCALABILITY_SERVICE_NAME}
    Set Suite Variable    ${SCALABILITY_EXPERIMENT_DIR}    ${experiment_dir}
    Create Directory    ${SCALABILITY_EXPERIMENT_DIR}
    Configure Scalability Authentication
    Capture Cluster Status Snapshot
    Prepare Simple Test Service File
    ${body}=    Get File    ${SCALABILITY_SERVICE_JSON}
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    Wait For Scalability Service Ready
    Configure Scalability Invocation Authentication
    Plan Scalability Load From Quotas
    Run Keyword If    ${SCALABILITY_BASELINE_ENABLED}    Measure Baseline Invocations
    Capture Run Configuration
    Run Keyword If    ${SCALABILITY_BASELINE_ENABLED} and ${SCALABILITY_CLEAN_JOBS}    Delete Scalability Jobs
    ${payload}=    Get File    ${SCALABILITY_PAYLOAD_FILE}
    Set Environment Variable    OSCAR_SERVICE_NAME    ${SCALABILITY_SERVICE_NAME}
    Set Environment Variable    SCALABILITY_PAYLOAD    ${payload}
    Set Environment Variable    LOCUST_WAIT_MIN    ${LOCUST_WAIT_MIN}
    Set Environment Variable    LOCUST_WAIT_MAX    ${LOCUST_WAIT_MAX}

Teardown Scalability Environment
    [Documentation]    Remove service, generated payloads, and environment variables.
    Run Keyword And Ignore Error    Build Scalability Experiment Artifact
    Run Keyword If    ${SCALABILITY_CLEAN_JOBS}    Delete Scalability Jobs
    Run Keyword If    ${SCALABILITY_CLEAN_SERVICE}    Delete Scalability Service
    Run Keyword And Ignore Error    Remove File    ${SCALABILITY_SERVICE_JSON}
    Run Keyword And Ignore Error    Remove Environment Variable    OSCAR_SERVICE_NAME
    Run Keyword And Ignore Error    Remove Environment Variable    OSCAR_ACCESS_TOKEN
    Run Keyword And Ignore Error    Remove Environment Variable    OSCAR_AUTHORIZATION_HEADER
    Run Keyword And Ignore Error    Remove Environment Variable    OSCAR_INVOCATION_AUTHORIZATION_HEADER
    Run Keyword And Ignore Error    Remove Environment Variable    OSCAR_LOAD_MODE
    Run Keyword And Ignore Error    Remove Environment Variable    SCALABILITY_PAYLOAD
    Run Keyword And Ignore Error    Remove Environment Variable    LOCUST_WAIT_MIN
    Run Keyword And Ignore Error    Remove Environment Variable    LOCUST_WAIT_MAX

Run Scalability Steps
    [Documentation]    Execute one Locust run per user-count step.
    [Arguments]    ${mode}
    @{steps}=    Split String    ${SCALABILITY_EFFECTIVE_USERS}    ,
    Run Keyword If    '${mode}' == 'async' and ${SCALABILITY_ASYNC_WARMUP_ENABLED}    Run Async Warmup
    FOR    ${users}    IN    @{steps}
        ${users}=    Strip String    ${users}
        Log To Console    OSCAR scalability step: mode=${mode}, users=${users}, run_time=${SCALABILITY_RUN_TIME}, spawn_rate=${SCALABILITY_SPAWN_RATE}
        Run Keyword If    '${mode}' == 'async' and ${SCALABILITY_CLEAN_JOBS}    Delete Scalability Jobs
        Run Locust Invocation Test    ${mode}    ${users}
        Run Keyword If    '${mode}' == 'async'    Sleep    ${SCALABILITY_ASYNC_SETTLE_TIME}
        Collect Scalability Results    ${mode}    ${users}
    END

Run Locust Invocation Test
    [Documentation]    Execute Locust headlessly for a single scalability step.
    [Arguments]    ${mode}    ${users}
    Set Environment Variable    OSCAR_LOAD_MODE    ${mode}
    Configure Locust Wait For Mode    ${mode}
    ${output_prefix}=    Get Scalability Output Prefix    ${mode}    ${users}
    ${command}=    Create List    locust    -f    ${LOCUSTFILE}    --headless    -u    ${users}
    ...    -r    ${SCALABILITY_SPAWN_RATE}    -t    ${SCALABILITY_RUN_TIME}    --host=${OSCAR_ENDPOINT}
    ...    --stop-timeout=60    --csv=${output_prefix}    --csv-full-history    --html=${output_prefix}.html
    ...    --json-file=${output_prefix}_locust    --exit-code-on-error=0
    ${result}=    Run Process    @{command}    stdout=True    stderr=True    cwd=${CURDIR}
    Log    ${result.stdout}
    Log    ${result.stderr}
    Should Be Equal As Integers    ${result.rc}    0
    Log    Locust artifacts written using prefix ${output_prefix}

Configure Locust Wait For Mode
    [Documentation]    Use async-specific pacing so job submit rate is not tied only to HTTP acceptance latency.
    [Arguments]    ${mode}
    IF    '${mode}' == 'async'
        Set Environment Variable    LOCUST_WAIT_MIN    ${SCALABILITY_ASYNC_WAIT_MIN}
        Set Environment Variable    LOCUST_WAIT_MAX    ${SCALABILITY_ASYNC_WAIT_MAX}
        Log    Async Locust wait configured: min=${SCALABILITY_ASYNC_WAIT_MIN}, max=${SCALABILITY_ASYNC_WAIT_MAX}
    ELSE
        Set Environment Variable    LOCUST_WAIT_MIN    ${LOCUST_WAIT_MIN}
        Set Environment Variable    LOCUST_WAIT_MAX    ${LOCUST_WAIT_MAX}
        Log    Locust wait configured: min=${LOCUST_WAIT_MIN}, max=${LOCUST_WAIT_MAX}
    END

Configure Scalability Authentication
    [Documentation]    Configure either OIDC user bearer auth or OSCAR Basic auth for OSCAR Manager operations.
    ${auth_mode}=    Convert To Lower Case    ${SCALABILITY_AUTH_MODE}
    IF    '${auth_mode}' == 'oscar' or '${auth_mode}' == 'basic' or '${auth_mode}' == 'admin'
        Variable Should Exist    ${BASIC_USER}    BASIC_USER must be defined in the selected cluster file to use SCALABILITY_AUTH_MODE=oscar.
        VAR    &{HEADERS}=    Authorization=Basic ${BASIC_USER}    Content-Type=text/json    Accept=application/json
        ...    scope=SUITE
        VAR    &{HEADERS_OSCAR}=    Authorization=Basic ${BASIC_USER}    Content-Type=text/json    Accept=application/json
        ...    scope=SUITE
        Set Suite Variable    ${ACCESS_TOKEN}    ${EMPTY}
        Set Suite Variable    ${USER}    oscar
        Set Suite Variable    ${USER_SHORT_ID}    oscar
    ELSE
        Check Valid OIDC Token
        ${access_token}=    Get Access Token
        Set Suite Variable    ${ACCESS_TOKEN}    ${access_token}
    END
    ${auth_header}=    Get From Dictionary    ${HEADERS}    Authorization
    Set Suite Variable    ${SCALABILITY_AUTH_HEADER}    ${auth_header}
    Set Environment Variable    OSCAR_AUTHORIZATION_HEADER    ${SCALABILITY_AUTH_HEADER}
    Run Keyword If    '${ACCESS_TOKEN}' != ''    Set Environment Variable    OSCAR_ACCESS_TOKEN    ${ACCESS_TOKEN}
    Log To Console    Scalability authentication mode: ${auth_mode}
    Run Keyword If    '${auth_mode}' == 'oscar' or '${auth_mode}' == 'basic' or '${auth_mode}' == 'admin'    Validate OSCAR Basic Authentication

Configure Scalability Invocation Authentication
    [Documentation]    Configure the Authorization header used by /run and /job invocations.
    ${auth_mode}=    Convert To Lower Case    ${SCALABILITY_AUTH_MODE}
    IF    '${auth_mode}' == 'oscar' or '${auth_mode}' == 'basic' or '${auth_mode}' == 'admin'
        ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SCALABILITY_SERVICE_NAME}    expected_status=200
        ${previous_log_level}=    Set Log Level    NONE
        ${service_token}=    Evaluate    json.loads($response.content).get("token")    json
        Should Not Be Empty
        ...    ${service_token}
        ...    msg=The service ${SCALABILITY_SERVICE_NAME} does not expose an invocation token. Cannot invoke /run or /job with SCALABILITY_AUTH_MODE=${SCALABILITY_AUTH_MODE}.
        ${invocation_header}=    Set Variable    Bearer ${service_token}
        Set Suite Variable    ${SCALABILITY_INVOCATION_AUTH_SOURCE}    service-token
    ELSE
        ${previous_log_level}=    Set Log Level    NONE
        ${invocation_header}=    Set Variable    ${SCALABILITY_AUTH_HEADER}
        Set Suite Variable    ${SCALABILITY_INVOCATION_AUTH_SOURCE}    user-bearer
    END
    Set Suite Variable    ${SCALABILITY_INVOCATION_AUTH_HEADER}    ${invocation_header}
    Set Environment Variable    OSCAR_INVOCATION_AUTHORIZATION_HEADER    ${SCALABILITY_INVOCATION_AUTH_HEADER}
    Set Log Level    ${previous_log_level}
    Log To Console    Scalability invocation authentication: ${SCALABILITY_INVOCATION_AUTH_SOURCE}

Capture Cluster Status Snapshot
    [Documentation]    Store a non-blocking /system/status snapshot before the experiment workload starts.
    ${status_path}=    Catenate    SEPARATOR=/    ${SCALABILITY_EXPERIMENT_DIR}    cluster-status.json
    ${command}=    Create List    python3    ${CLUSTER_STATUS_CAPTURE}
    ...    --endpoint    ${OSCAR_ENDPOINT}
    ...    --output    ${status_path}
    ...    --ssl-verify    ${SSL_VERIFY}
    ${result}=    Run Process    @{command}    stdout=True    stderr=True    cwd=${CURDIR}
    Log    ${result.stdout}
    Log    ${result.stderr}
    Should Be Equal As Integers    ${result.rc}    0
    ${snapshot}=    Evaluate    json.loads($result.stdout)    json
    ${resources}=    Evaluate    $snapshot.get("resources", {})
    Set Suite Variable    ${SCALABILITY_CLUSTER_RESOURCES}    ${resources}
    ${available}=    Get From Dictionary    ${snapshot}    available
    ${status_code}=    Get From Dictionary    ${snapshot}    status_code
    ${cpu_total_free}=    Evaluate    $resources.get("cpu", {}).get("total_free_cores")
    ${cpu_max_node_free}=    Evaluate    $resources.get("cpu", {}).get("max_free_on_node_cores")
    ${memory_total_free}=    Evaluate    $resources.get("memory", {}).get("total_free_mib")
    ${memory_max_node_free}=    Evaluate    $resources.get("memory", {}).get("max_free_on_node_mib")
    Log To Console    Cluster status snapshot: available=${available}, status_code=${status_code}; total_free_cpu=${cpu_total_free} cores; max_node_free_cpu=${cpu_max_node_free} cores; total_free_memory=${memory_total_free} MiB; max_node_free_memory=${memory_max_node_free} MiB; saved to ${status_path}

Validate OSCAR Basic Authentication
    [Documentation]    Fail fast when BASIC_USER from the cluster file is rejected by OSCAR.
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services    expected_status=ANY
    Should Be Equal As Integers
    ...    ${response.status_code}
    ...    200
    ...    msg=SCALABILITY_AUTH_MODE=oscar selected, but OSCAR rejected BASIC_USER from the cluster file at ${OSCAR_ENDPOINT}/system/services with HTTP ${response.status_code}. Check that the cluster file contains current oscar Basic auth credentials and that Basic auth is enabled on this endpoint.
    Log To Console    OSCAR Basic authentication validated for ${OSCAR_ENDPOINT}

Plan Scalability Load From Quotas
    [Documentation]    Compute the user-step plan from /system/quotas/user and print experiment metadata.
    IF    not ${SCALABILITY_USE_QUOTAS}
        Set Suite Variable    ${SCALABILITY_EFFECTIVE_USERS}    ${SCALABILITY_USERS}
        Log To Console    OSCAR scalability experiment: quotas disabled; users=${SCALABILITY_EFFECTIVE_USERS}; service_cpu=${SCALABILITY_SERVICE_CPU}; service_memory=${SCALABILITY_SERVICE_MEMORY}
        RETURN
    END
    ${command}=    Create List    python3    ${LOAD_PLANNER}
    ...    --endpoint    ${OSCAR_ENDPOINT}
    ...    --requested-users    ${SCALABILITY_USERS}
    ...    --service-cpu    ${SCALABILITY_SERVICE_CPU}
    ...    --service-memory    ${SCALABILITY_SERVICE_MEMORY}
    ...    --mode    ${SCALABILITY_QUOTA_MODE}
    ...    --ssl-verify    ${SSL_VERIFY}
    ${result}=    Run Process    @{command}    stdout=True    stderr=True    cwd=${CURDIR}
    Log    ${result.stdout}
    Log    ${result.stderr}
    Should Be Equal As Integers    ${result.rc}    0
    ${plan}=    Evaluate    json.loads($result.stdout)    json
    ${effective_users}=    Evaluate    ",".join(str(item) for item in $plan["effective_users"])
    Set Suite Variable    ${SCALABILITY_EFFECTIVE_USERS}    ${effective_users}
    ${plan_path}=    Catenate    SEPARATOR=/    ${SCALABILITY_EXPERIMENT_DIR}    quota-plan.json
    Create File    ${plan_path}    ${result.stdout}
    Print Scalability Experiment Plan    ${plan}    ${plan_path}

Print Scalability Experiment Plan
    [Arguments]    ${plan}    ${plan_path}
    ${quota_available}=    Get From Dictionary    ${plan}    quota_available
    ${requested_users}=    Evaluate    ",".join(str(item) for item in $plan["requested_users"])
    ${effective_users}=    Evaluate    ",".join(str(item) for item in $plan["effective_users"])
    ${service_cpu}=    Evaluate    $plan["service"]["cpu"]
    ${service_memory}=    Evaluate    $plan["service"]["memory_mib"]
    Log To Console    \nOSCAR scalability experiment
    Log To Console    Service: ${SCALABILITY_SERVICE_NAME} (${SCALABILITY_SERVICE_CPU} CPU, ${SCALABILITY_SERVICE_MEMORY}; parsed ${service_cpu} CPU, ${service_memory} MiB)
    Log To Console    Requested user steps: ${requested_users}
    Log To Console    Effective user steps: ${effective_users}
    Log To Console    Run time per step: ${SCALABILITY_RUN_TIME}; spawn rate: ${SCALABILITY_SPAWN_RATE}; async settle: ${SCALABILITY_ASYNC_SETTLE_TIME}
    ${has_cluster_resources}=    Evaluate    isinstance($SCALABILITY_CLUSTER_RESOURCES, dict) and bool($SCALABILITY_CLUSTER_RESOURCES)
    IF    ${has_cluster_resources}
        ${nodes_count}=    Evaluate    $SCALABILITY_CLUSTER_RESOURCES.get("nodes_count")
        ${cluster_cpu_total_free}=    Evaluate    $SCALABILITY_CLUSTER_RESOURCES.get("cpu", {}).get("total_free_cores")
        ${cluster_cpu_max_node_free}=    Evaluate    $SCALABILITY_CLUSTER_RESOURCES.get("cpu", {}).get("max_free_on_node_cores")
        ${cluster_memory_total_free}=    Evaluate    $SCALABILITY_CLUSTER_RESOURCES.get("memory", {}).get("total_free_mib")
        ${cluster_memory_max_node_free}=    Evaluate    $SCALABILITY_CLUSTER_RESOURCES.get("memory", {}).get("max_free_on_node_mib")
        Log To Console    Cluster resources from /system/status: nodes=${nodes_count}; total_free_cpu=${cluster_cpu_total_free} cores; max_node_free_cpu=${cluster_cpu_max_node_free} cores; total_free_memory=${cluster_memory_total_free} MiB; max_node_free_memory=${cluster_memory_max_node_free} MiB
    END
    IF    ${quota_available}
        ${quota_path}=    Get From Dictionary    ${plan}    quota_path
        ${cpu_max_raw}=    Evaluate    $plan["quota"]["cpu_max_raw"]
        ${memory_max_raw}=    Evaluate    $plan["quota"]["memory_max_raw"]
        ${cpu_available}=    Evaluate    $plan["quota"]["cpu_available"]
        ${memory_available}=    Evaluate    $plan["quota"]["memory_available_mib"]
        ${safe_parallel}=    Evaluate    $plan["limits"]["safe_parallel"]
        ${cpu_parallel}=    Evaluate    $plan["limits"]["cpu_parallel"]
        ${memory_parallel}=    Evaluate    $plan["limits"]["memory_parallel"]
        Log To Console    Quota source: ${quota_path}
        Log To Console    Quota raw max: cpu=${cpu_max_raw}, memory=${memory_max_raw}
        Log To Console    Available quota: cpu=${cpu_available} cores, memory=${memory_available} MiB
        Log To Console    Estimated parallel capacity: cpu=${cpu_parallel}, memory=${memory_parallel}, safe=${safe_parallel}; mode=${SCALABILITY_QUOTA_MODE}
    ELSE
        ${reason}=    Get From Dictionary    ${plan}    reason
        Log To Console    Quota source: unavailable (${reason}); using requested user steps unchanged
    END
    Log To Console    Quota plan saved to: ${plan_path}

Measure Baseline Invocations
    [Documentation]    Measure first-ready and warm isolated invocations before Locust load.
    ${baseline_path}=    Catenate    SEPARATOR=/    ${SCALABILITY_EXPERIMENT_DIR}    baseline.json
    ${command}=    Create List    python3    ${BASELINE_MEASURER}
    ...    --endpoint    ${OSCAR_ENDPOINT}
    ...    --service    ${SCALABILITY_SERVICE_NAME}
    ...    --payload-file    ${SCALABILITY_PAYLOAD_FILE}
    ...    --output    ${baseline_path}
    ...    --ssl-verify    ${SSL_VERIFY}
    ...    --sync-retries    ${SCALABILITY_BASELINE_SYNC_RETRIES}
    ...    --sync-retry-interval    ${SCALABILITY_BASELINE_SYNC_RETRY_INTERVAL}
    ...    --async-timeout    ${SCALABILITY_BASELINE_ASYNC_TIMEOUT}
    ...    --async-poll-interval    ${SCALABILITY_BASELINE_ASYNC_POLL_INTERVAL}
    ${result}=    Run Process    @{command}    stdout=True    stderr=True    cwd=${CURDIR}
    Log    ${result.stdout}
    Log    ${result.stderr}
    Should Be Equal As Integers    ${result.rc}    0
    ${baseline}=    Evaluate    json.loads($result.stdout)    json
    ${sync_first_ms}=    Evaluate    $baseline.get("sync", {}).get("first_ready", {}).get("latency_ms")
    ${sync_warm_ms}=    Evaluate    $baseline.get("sync", {}).get("warm", {}).get("latency_ms")
    ${sync_first_attempts}=    Evaluate    $baseline.get("sync", {}).get("first_ready", {}).get("attempts")
    ${sync_warm_attempts}=    Evaluate    $baseline.get("sync", {}).get("warm", {}).get("attempts")
    ${async_first_submit_ms}=    Evaluate    $baseline.get("async", {}).get("first_ready", {}).get("submit", {}).get("latency_ms")
    ${async_first_e2e_s}=    Evaluate    $baseline.get("async", {}).get("first_ready", {}).get("job", {}).get("completion_seconds")
    ${async_warm_submit_ms}=    Evaluate    $baseline.get("async", {}).get("warm", {}).get("submit", {}).get("latency_ms")
    ${async_warm_e2e_s}=    Evaluate    $baseline.get("async", {}).get("warm", {}).get("job", {}).get("completion_seconds")
    Log To Console    Invocation baseline: sync_first_ready=${sync_first_ms} ms (${sync_first_attempts} attempts); sync_warm=${sync_warm_ms} ms (${sync_warm_attempts} attempts); async_first_submit=${async_first_submit_ms} ms; async_first_e2e=${async_first_e2e_s} s; async_warm_submit=${async_warm_submit_ms} ms; async_warm_e2e=${async_warm_e2e_s} s; saved to ${baseline_path}

Run Async Warmup
    [Documentation]    Submit and wait for warm-up async jobs before measured async Locust steps.
    ${warmup_path}=    Catenate    SEPARATOR=/    ${SCALABILITY_EXPERIMENT_DIR}    async-warmup.json
    ${command}=    Create List    python3    ${ASYNC_WARMUP}
    ...    --endpoint    ${OSCAR_ENDPOINT}
    ...    --service    ${SCALABILITY_SERVICE_NAME}
    ...    --payload-file    ${SCALABILITY_PAYLOAD_FILE}
    ...    --output    ${warmup_path}
    ...    --ssl-verify    ${SSL_VERIFY}
    ...    --jobs    ${SCALABILITY_ASYNC_WARMUP_JOBS}
    ...    --submit-interval    ${SCALABILITY_ASYNC_WARMUP_SUBMIT_INTERVAL}
    ...    --async-timeout    ${SCALABILITY_BASELINE_ASYNC_TIMEOUT}
    ...    --async-poll-interval    ${SCALABILITY_BASELINE_ASYNC_POLL_INTERVAL}
    ${result}=    Run Process    @{command}    stdout=True    stderr=True    cwd=${CURDIR}
    Log    ${result.stdout}
    Log    ${result.stderr}
    Should Be Equal As Integers    ${result.rc}    0
    ${warmup}=    Evaluate    json.loads($result.stdout)    json
    ${summary}=    Evaluate    $warmup.get("summary", {})
    ${warmup_jobs}=    Evaluate    $summary.get("jobs")
    ${warmup_succeeded}=    Evaluate    $summary.get("succeeded")
    ${warmup_elapsed}=    Evaluate    $summary.get("elapsed_seconds")
    Log To Console    Async warm-up: jobs=${warmup_jobs}, succeeded=${warmup_succeeded}, elapsed=${warmup_elapsed} s; saved to ${warmup_path}
    Run Keyword If    ${SCALABILITY_CLEAN_JOBS}    Delete Scalability Jobs

Capture Run Configuration
    [Documentation]    Store non-secret variables and command metadata required to reproduce the experiment.
    ${config_path}=    Catenate    SEPARATOR=/    ${SCALABILITY_EXPERIMENT_DIR}    run-configuration.json
    ${command}=    Create List    python3    ${RUN_CONFIG_WRITER}
    ...    --output    ${config_path}
    ...    --endpoint    ${OSCAR_ENDPOINT}
    ...    --service    ${SCALABILITY_SERVICE_NAME}
    ...    --experiment-dir    ${SCALABILITY_EXPERIMENT_DIR}
    ...    --variable    OSCAR_ENDPOINT=${OSCAR_ENDPOINT}
    ...    --variable    AUTHENTICATION_PROCESS=${AUTHENTICATION_PROCESS}
    ...    --variable    SCALABILITY_AUTH_MODE=${SCALABILITY_AUTH_MODE}
    ...    --variable    SCALABILITY_INVOCATION_AUTH_SOURCE=${SCALABILITY_INVOCATION_AUTH_SOURCE}
    ...    --variable    SSL_VERIFY=${SSL_VERIFY}
    ...    --variable    LOCAL_TESTING=${LOCAL_TESTING}
    ...    --variable    SCALABILITY_USERS=${SCALABILITY_USERS}
    ...    --variable    SCALABILITY_EFFECTIVE_USERS=${SCALABILITY_EFFECTIVE_USERS}
    ...    --variable    SCALABILITY_SPAWN_RATE=${SCALABILITY_SPAWN_RATE}
    ...    --variable    SCALABILITY_RUN_TIME=${SCALABILITY_RUN_TIME}
    ...    --variable    SCALABILITY_ASYNC_SETTLE_TIME=${SCALABILITY_ASYNC_SETTLE_TIME}
    ...    --variable    SCALABILITY_ASYNC_WAIT_MIN=${SCALABILITY_ASYNC_WAIT_MIN}
    ...    --variable    SCALABILITY_ASYNC_WAIT_MAX=${SCALABILITY_ASYNC_WAIT_MAX}
    ...    --variable    SCALABILITY_SERVICE_BASE=${SCALABILITY_SERVICE_BASE}
    ...    --variable    SCALABILITY_SERVICE_NAME=${SCALABILITY_SERVICE_NAME}
    ...    --variable    SCALABILITY_SERVICE_CPU=${SCALABILITY_SERVICE_CPU}
    ...    --variable    SCALABILITY_SERVICE_MEMORY=${SCALABILITY_SERVICE_MEMORY}
    ...    --variable    SCALABILITY_PAYLOAD_FILE=${SCALABILITY_PAYLOAD_FILE}
    ...    --variable    SCALABILITY_USE_QUOTAS=${SCALABILITY_USE_QUOTAS}
    ...    --variable    SCALABILITY_QUOTA_MODE=${SCALABILITY_QUOTA_MODE}
    ...    --variable    SCALABILITY_SYNC_ENABLED=${SCALABILITY_SYNC_ENABLED}
    ...    --variable    SCALABILITY_ASYNC_ENABLED=${SCALABILITY_ASYNC_ENABLED}
    ...    --variable    SCALABILITY_BASELINE_ENABLED=${SCALABILITY_BASELINE_ENABLED}
    ...    --variable    SCALABILITY_BASELINE_SYNC_RETRIES=${SCALABILITY_BASELINE_SYNC_RETRIES}
    ...    --variable    SCALABILITY_BASELINE_SYNC_RETRY_INTERVAL=${SCALABILITY_BASELINE_SYNC_RETRY_INTERVAL}
    ...    --variable    SCALABILITY_BASELINE_ASYNC_TIMEOUT=${SCALABILITY_BASELINE_ASYNC_TIMEOUT}
    ...    --variable    SCALABILITY_BASELINE_ASYNC_POLL_INTERVAL=${SCALABILITY_BASELINE_ASYNC_POLL_INTERVAL}
    ...    --variable    SCALABILITY_ASYNC_WARMUP_ENABLED=${SCALABILITY_ASYNC_WARMUP_ENABLED}
    ...    --variable    SCALABILITY_ASYNC_WARMUP_JOBS=${SCALABILITY_ASYNC_WARMUP_JOBS}
    ...    --variable    SCALABILITY_ASYNC_WARMUP_SUBMIT_INTERVAL=${SCALABILITY_ASYNC_WARMUP_SUBMIT_INTERVAL}
    ...    --variable    SCALABILITY_CLEAN_JOBS=${SCALABILITY_CLEAN_JOBS}
    ...    --variable    SCALABILITY_CLEAN_SERVICE=${SCALABILITY_CLEAN_SERVICE}
    ...    --variable    LOCUST_WAIT_MIN=${LOCUST_WAIT_MIN}
    ...    --variable    LOCUST_WAIT_MAX=${LOCUST_WAIT_MAX}
    ${result}=    Run Process    @{command}    stdout=True    stderr=True    cwd=${CURDIR}
    Log    ${result.stdout}
    Log    ${result.stderr}
    Should Be Equal As Integers    ${result.rc}    0
    Log To Console    Run configuration saved to: ${config_path}

Collect Scalability Results
    [Documentation]    Generate JSON and Markdown summaries for the Locust step using OSCAR Manager API.
    [Arguments]    ${mode}    ${users}
    ${output_prefix}=    Get Scalability Output Prefix    ${mode}    ${users}
    ${summary_json}=    Set Variable    ${output_prefix}_summary.json
    ${summary_md}=      Set Variable    ${output_prefix}_summary.md
    ${command}=    Create List    python3    ${COLLECTOR}
    ...    --endpoint    ${OSCAR_ENDPOINT}
    ...    --service    ${SCALABILITY_SERVICE_NAME}
    ...    --mode    ${mode}
    ...    --locust-prefix    ${output_prefix}
    ...    --output    ${summary_json}
    ...    --markdown    ${summary_md}
    ...    --ssl-verify    ${SSL_VERIFY}
    ${result}=    Run Process    @{command}    stdout=True    stderr=True    cwd=${CURDIR}
    Log    ${result.stdout}
    Log    ${result.stderr}
    Should Be Equal As Integers    ${result.rc}    0
    Log    Scalability summary written to ${summary_json} and ${summary_md}
    ${summary}=    Evaluate    json.load(open(r'''${summary_json}''', encoding="utf-8"))    json
    ${totals}=    Evaluate    $summary.get("locust", {}).get("totals", {})
    ${request_count}=    Evaluate    int($totals.get("request_count", 0) or 0)
    ${failure_count}=    Evaluate    int($totals.get("failure_count", 0) or 0)
    ${failure_rate}=    Evaluate    (100.0 * $failure_count / $request_count) if $request_count else 0.0
    ${failure_rate_text}=    Evaluate    f"{float($failure_rate):.2f}"
    Log To Console    OSCAR scalability result: mode=${mode}, users=${users}, requests=${request_count}, failures=${failure_count}, failure_rate=${failure_rate_text}%; summary=${summary_json}
    IF    ${failure_count} > 0
        Log To Console    WARNING: Locust recorded ${failure_count} failed HTTP requests for mode=${mode}, users=${users}. The Robot test keeps running so the failure profile is preserved in the experiment artifact.
    END

Build Scalability Experiment Artifact
    [Documentation]    Build a portable experiment JSON and publish the D3 static viewer.
    ${command}=    Create List    python3    ${EXPERIMENT_BUILDER}
    ...    --experiment-dir    ${SCALABILITY_EXPERIMENT_DIR}
    ...    --output-root    ${SCALABILITY_OUTPUT_DIR}
    ...    --service    ${SCALABILITY_SERVICE_NAME}
    ...    --viewer-src    ${SCALABILITY_VIEWER_DIR}
    ...    --endpoint    ${OSCAR_ENDPOINT}
    ${result}=    Run Process    @{command}    stdout=True    stderr=True    cwd=${CURDIR}
    Log    ${result.stdout}
    Log    ${result.stderr}
    Should Be Equal As Integers    ${result.rc}    0
    ${artifact_info}=    Evaluate    json.loads($result.stdout)    json
    Log To Console    OSCAR scalability experiment artifact: ${artifact_info["experiment"]}
    Log To Console    OSCAR scalability viewer: ${artifact_info["viewer"]}
    Log To Console    OSCAR scalability published viewer copy: ${artifact_info["published_viewer"]}

Prepare Simple Test Service File
    [Documentation]    Generate the simple-test service definition for this run.
    ${yaml_content}=    Get File    ${SCALABILITY_SERVICE_FILE}
    ${service_content}=    Set Service File VO    ${yaml_content}
    ${modified_content}=    Set Variable    ${service_content}[functions][oscar][0][oscar-cluster]
    ${script}=    Get File    ${SCALABILITY_SERVICE_SCRIPT}
    Set To Dictionary    ${modified_content}    script=${script}
    Set To Dictionary    ${modified_content}    name=${SCALABILITY_SERVICE_NAME}
    Set To Dictionary    ${modified_content}    cpu=${SCALABILITY_SERVICE_CPU}
    Set To Dictionary    ${modified_content}    memory=${SCALABILITY_SERVICE_MEMORY}
    Set To Dictionary    ${modified_content}    isolation_level=SERVICE
    ${input_entries}=    Get From Dictionary    ${modified_content}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${SCALABILITY_SERVICE_NAME}/input
    ${output_entries}=    Get From Dictionary    ${modified_content}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${SCALABILITY_SERVICE_NAME}/output
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${SCALABILITY_SERVICE_JSON}    ${service_content_json}

Wait For Scalability Service Ready
    [Documentation]    Poll service status until it is ready.
    Wait Until Keyword Succeeds    240s    5s    Scalability Service Should Be Ready

Scalability Service Should Be Ready
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SCALABILITY_SERVICE_NAME}    expected_status=200
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${status}=    Evaluate    (lambda d: d.get('status') if not isinstance(d.get('status'), dict) else d['status'].get('state') or d['status'].get('phase') or d['status'].get('condition'))(${payload})    json
    ${ready}=    Evaluate    str(${status}).lower() in ("ready","running","available","succeeded") or bool(${payload}.get('ready')) or bool(${payload}.get('token'))    json
    Should Be True    ${ready}    Service not ready yet (status=${status})

Delete Scalability Jobs
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${SCALABILITY_SERVICE_NAME}?all=true    expected_status=ANY
    Log    Delete jobs response: ${response.status_code}

Delete Scalability Service
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SCALABILITY_SERVICE_NAME}    expected_status=ANY
    Log    Delete service response: ${response.status_code}

Get Scalability Output Prefix
    [Arguments]    ${mode}    ${users}
    ${prefix}=    Catenate    SEPARATOR=/    ${SCALABILITY_EXPERIMENT_DIR}    ${SCALABILITY_SERVICE_NAME}-${mode}-${users}u
    RETURN    ${prefix}

GET With Defaults
    [Arguments]    ${url}    ${expected_status}=200    ${headers}=${HEADERS}
    ${headers}=    Run Keyword If    '${LOCAL_TESTING}'=='True'    Set Variable    ${HEADERS_OSCAR}    ELSE    Set Variable    ${headers}
    ${response}=    GET    url=${url}    expected_status=${expected_status}    verify=${SSL_VERIFY}    headers=&{headers}
    RETURN    ${response}

POST With Defaults
    [Arguments]    ${url}    ${data}    ${headers}=${HEADERS}
    ${headers}=    Run Keyword If    '${LOCAL_TESTING}'=='True'    Set Variable    ${HEADERS_OSCAR}    ELSE    Set Variable    ${headers}
    ${response}=    POST    url=${url}    data=${data}    expected_status=ANY    verify=${SSL_VERIFY}    headers=&{headers}
    RETURN    ${response}

DELETE With Defaults
    [Arguments]    ${url}    ${expected_status}=204    ${headers}=${HEADERS}
    ${headers}=    Run Keyword If    '${LOCAL_TESTING}'=='True'    Set Variable    ${HEADERS_OSCAR}    ELSE    Set Variable    ${headers}
    ${response}=    DELETE    url=${url}    expected_status=${expected_status}    verify=${SSL_VERIFY}    headers=&{headers}
    RETURN    ${response}
