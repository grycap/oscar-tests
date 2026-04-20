*** Settings ***
Documentation       Validate job concurrency using the sleep-test service, sizing the burst based on /system/quotas

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/api_call.resource
Resource            ${CURDIR}/../../resources/service.resource

Library             Collections
Library             DateTime
Library             yaml
Library             String


Suite Setup         Run Keywords    Check Valid OIDC Token    AND    Assign Random Service Name    AND    Assign Random String
Suite Teardown      Run Keywords    Restore User Memory Quota    AND    Cleanup Quotas Services


*** Variables ***
${SERVICE_BASE}                 sleep-test
${SERVICE_NAME}                 ${SERVICE_BASE}
${SLEEP_SERVICE_FILE}           ${DATA_DIR}/sleep-test.yaml
${SLEEP_SCRIPT_FILE}            ${DATA_DIR}/sleep-test.sh
${NGINX_SCRIPT_FILE}            ${DATA_DIR}/expose_services/nginxscript.sh
${SERVICE_CPU}                  1.0
${PARALLEL_LIMIT}               0
${JOB_COUNT}                    0
${MAX_RUNNING_SEEN}             0
${MEMORY_MAX_MI}                0
${ORIG_MEM_MAX_MI}              0
${ORIG_CPU_CORES}               0
${NEW_CPU_CORES}                0
${SERVICE_NAME_ROBOT}           robot-oscar-cluster
${SERVICE_NAME_NGINX}           robot-test-nginx
${SYNC_READY_TIMEOUT}           120s
${ASYNC_READY_TIMEOUT}          120s
${EXPOSED_READY_TIMEOUT}        120s
${FAST_RETRY_INTERVAL}          5s
${RUN_REQUEST_TIMEOUT}          12
${RUN_REJECTION_TIMEOUT}        45


*** Test Cases ***
Get quotas and plan burst
    [Documentation]    Retrieve quotas via /system/quotas (fallback /system/quotas/user) and compute how many jobs to launch.
    ${quota_resp}=    Fetch Quotas Response
    Log    ${quota_resp.content}
    ${quota_json}=    Evaluate    json.loads($quota_resp.content)    json
    ${cpu_res}=    Get From Dictionary    ${quota_json["resources"]}    cpu
    ${cpu_max}=    Get From Dictionary    ${cpu_res}    max
    ${cpu_used}=    Get From Dictionary    ${cpu_res}    used
    ${available_cpu}=    Compute Available CPU    ${cpu_max}    ${cpu_used}
    ${parallel}=    Compute Parallel Limit    ${available_cpu}    ${SERVICE_CPU}
    Set Suite Variable    ${PARALLEL_LIMIT}    ${parallel}
    ${orig_cpu_cores}=    Parse CPU Quantity To Float    ${cpu_max}
    Set Suite Variable    ${ORIG_CPU_CORES}    ${orig_cpu_cores}
    Skip If    ${PARALLEL_LIMIT} < 2    Not enough free CPU to validate concurrency (needs at least 2)
    ${job_count}=    Evaluate    ${PARALLEL_LIMIT} + 2
    Set Suite Variable    ${JOB_COUNT}    ${job_count}
    Log         Job plan -> base parallel limit: ${PARALLEL_LIMIT}, jobs to submit now: ${JOB_COUNT}
    ${mem_res}=    Get From Dictionary    ${quota_json["resources"]}    memory
    ${mem_max}=    Get From Dictionary    ${mem_res}    max
    ${mem_used}=   Get From Dictionary    ${mem_res}    used
    ${max_mib}=    Parse Memory Quantity To Mib    ${mem_max}
    Log         Current memory quota: max=${mem_max} (${max_mib} Mi), used=${mem_used}
    Set Suite Variable    ${MEMORY_MAX_MI}    ${max_mib}
    Set Suite Variable    ${ORIG_MEM_MAX_MI}    ${max_mib}
    OSCAR Kueue Config Should Be Enabled

#Create sleep-test service
#    [Documentation]    Deploy the sleep-test service with a random name.
#    Prepare Sleep Service File
#    ${body}=    Get File    ${DATA_DIR}/service_file.json
#    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
#    Log    ${response.content}
#    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
#    # Verify the service can be read to confirm the expected name
#    ${read_resp}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
#    ${read_json}=    Evaluate    json.loads($read_resp.content)    json
#    ${read_name}=    Get From Dictionary    ${read_json}    name
#    Should Be Equal As Strings    ${read_name}    ${SERVICE_NAME}

#Submit jobs and verify concurrency
#    [Documentation]    Launch N+2 async jobs and ensure only N (quota) are running.
#    Skip If    ${JOB_COUNT} < 2    No jobs were planned (check quotas)
#    ${body}=    Get File    ${INVOKE_FILE}
#    Log         Submitting ${JOB_COUNT} jobs with resources -> cpu=${SERVICE_CPU}, memory=256Mi (service spec)
#    FOR    ${i}    IN RANGE    ${JOB_COUNT}
#        ${job_resp}=    POST With Defaults    url=${OSCAR_ENDPOINT}/job/${SERVICE_NAME}    data=${body}
#        Should Be Equal As Strings    ${job_resp.status_code}    201
#    END
#    ${max_running}    ${completed_jobs}=    Track Job Concurrency Until Done    ${SERVICE_NAME}    ${JOB_COUNT}    ${HEADERS_OSCAR}
#    Set Suite Variable    ${MAX_RUNNING_SEEN}    ${max_running}
#    Should Be Equal As Integers    ${max_running}    ${PARALLEL_LIMIT}    msg=Expected to cap at quota (${PARALLEL_LIMIT}) concurrent jobs
#    Should Be Equal As Integers    ${completed_jobs}    ${JOB_COUNT}

#Increase CPU quota allows one more job
#    [Documentation]    Increase CPU quota slightly and verify one more job can run concurrently.
#    ${new_cpu_cores}=    Evaluate    ${ORIG_CPU_CORES} + ${SERVICE_CPU}
#    Update User CPU Quota    ${new_cpu_cores}
#    ${quota_check}=    Fetch Quotas Response
#    ${quota_json}=    Evaluate    json.loads($quota_check.content)    json
#    ${cpu_res}=    Get From Dictionary    ${quota_json["resources"]}    cpu
#    ${cpu_max}=    Get From Dictionary    ${cpu_res}    max
#    ${cpu_max_cores}=    Parse CPU Quantity To Float    ${cpu_max}
#    Log         Updated CPU quota: max=${cpu_max} (${cpu_max_cores} cores)
#    Run Keyword If    ${cpu_max_cores} <= ${ORIG_CPU_CORES}    Fail    CPU quota did not increase (old=${ORIG_CPU_CORES}, new=${cpu_max_cores})
#    Set Suite Variable    ${NEW_CPU_CORES}    ${cpu_max_cores}
#    ${new_parallel}=    Compute Parallel Limit    ${cpu_max_cores}    ${SERVICE_CPU}
#    ${job_count}=    Evaluate    ${new_parallel} + 1
#    Log         Submitting ${job_count} jobs after CPU increase; expect max running >= ${PARALLEL_LIMIT + 1}
#    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}?all=true
#    ${body}=    Get File    ${INVOKE_FILE}
#    FOR    ${i}    IN RANGE    ${job_count}
#        ${job_resp}=    POST With Defaults    url=${OSCAR_ENDPOINT}/job/${SERVICE_NAME}    data=${body}
#        Should Be Equal As Strings    ${job_resp.status_code}    201
#    END
#    ${max_running}    ${completed_jobs}=    Track Job Concurrency Until Done    ${SERVICE_NAME}    ${job_count}    ${HEADERS_OSCAR}
#    Should Be True    ${max_running} >= ${PARALLEL_LIMIT + 1}    msg=Expected at least one more concurrent job after quota increase
#    Should Be Equal As Integers    ${completed_jobs}    ${job_count}

#Delete sleep-test service
#    [Documentation]    Delete the sleep-test service with a random name.
#    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
#    Should Be Equal As Strings    ${response.status_code}    204

Execute Synchronous Calls With Correct Resources
    [Documentation]    Test synchronous service calls with adequate resources for successful execution
    [Tags]    sync    correct-resources
    ${service_name}=    Set Variable    sync-correct-resources-${RANDOM_STRING}
    Prepare Service File With Correct Resources    ${service_name}
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    Wait For Quotas Service Ready    ${service_name}
    ${invoke_body}=    Get File    ${INVOKE_FILE}
    Wait Until Keyword Succeeds    ${SYNC_READY_TIMEOUT}    ${FAST_RETRY_INTERVAL}    Sync Invocation Should Contain Hello    ${service_name}    ${invoke_body}
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=ANY
    Should Be Equal As Strings    ${response.status_code}    204

Execute Synchronous Calls With Insufficient Resources
    [Documentation]    Validate that synchronous invocation with oversized resources returns a controlled Kueue rejection.
    [Tags]    sync    insufficient-resources
    ${service_name}=    Set Variable    sync-insufficient-${RANDOM_STRING}
    Prepare Service File With Insufficient Resources    ${service_name}
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    Service Resources Should Exceed Quotas    ${body}
    Wait For Quotas Service Ready    ${service_name}
    ${invoke_body}=    Get File    ${INVOKE_FILE}
    Sync Invocation Should Be Rejected By Kueue    ${service_name}    ${invoke_body}
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=ANY
    Should Be Equal As Strings    ${response.status_code}    204

Execute Asynchronous Calls With Correct Resources
    [Documentation]    Test asynchronous service calls with adequate resources for successful execution
    [Tags]    async    correct-resources
    ${service_name}=    Set Variable    async-correct-resources-${RANDOM_STRING}
    Prepare Service File With Correct Resources    ${service_name}
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    Wait For Quotas Service Ready    ${service_name}
    ${invoke_body}=    Get File    ${INVOKE_FILE}
    ${job_response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/job/${service_name}    data=${invoke_body}
    Should Be Equal As Strings    ${job_response.status_code}    201
    Wait Until Keyword Succeeds    ${ASYNC_READY_TIMEOUT}    ${FAST_RETRY_INTERVAL}    Async Job Should Have Status    ${service_name}    Succeeded
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=ANY
    Should Be Equal As Strings    ${response.status_code}    204

Execute Asynchronous Calls With Insufficient Resources
    [Documentation]    Test asynchronous service calls with inadequate resources expecting job queuing or failure
    [Tags]    async    insufficient-resources
    ${service_name}=    Set Variable    async-insufficient-${RANDOM_STRING}
    Prepare Service File With Insufficient Resources    ${service_name}
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    ${invoke_body}=    Get File    ${INVOKE_FILE}
    ${job_response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/job/${service_name}     data=${invoke_body}
    Should Be Equal As Strings    ${job_response.status_code}    201
    Wait Until Keyword Succeeds    60s    ${FAST_RETRY_INTERVAL}    Async Job Should Have Status    ${service_name}    Suspended
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=ANY
    Should Be Equal As Strings    ${response.status_code}    204

Execute Exposed Service With Correct Resources
    [Documentation]    Test exposed service calls with adequate resources for successful execution
    [Tags]    exposed    correct-resources
    ${service_name}=    Set Variable    exposed-correct-${RANDOM_STRING}
    Prepare Exposed Service With Correct Resources    ${service_name}
    ${body}=    Get File    ${DATA_DIR}/exposed_service_file.json
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    Wait Until Keyword Succeeds    ${EXPOSED_READY_TIMEOUT}    ${FAST_RETRY_INTERVAL}    Exposed Service Should Contain Nginx    ${service_name}
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=ANY
    Should Be Equal As Strings    ${response.status_code}    204

Execute Exposed Service With Insufficient Resources
    [Documentation]    Test exposed service calls with inadequate resources expecting service unavailable
    [Tags]    exposed    insufficient-resources
    ${service_name}=    Set Variable    exposed-insufficient-${RANDOM_STRING}
    Prepare Exposed Service With Insufficient Resources    ${service_name}
    ${body}=    Get File    ${DATA_DIR}/exposed_service_file.json
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Should Be True    '${response.status_code}' == '500' 
    Should Contain    ${response.content}    workload for exposed service '${service_name}' is NOT admitted 


*** Keywords ***
Fetch Quotas Response
    [Documentation]    Call /system/quotas and fallback to /system/quotas/user if needed.
    ${resp}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/quotas    expected_status=ANY
    IF    '${resp.status_code}' != '200'
        ${resp}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/quotas/user    expected_status=ANY
    END
    Should Be Equal As Strings    ${resp.status_code}    200
    RETURN    ${resp}

OSCAR Kueue Config Should Be Enabled
    [Documentation]    Fail fast when this quota suite is executed against a cluster without Kueue enabled.
    ${resp}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/config
    ${config}=    Evaluate    json.loads($resp.content)["config"]    json
    ${enabled}=    Get From Dictionary    ${config}    kueue_enable
    Should Be True    ${enabled}    Kueue must be enabled in OSCAR to run quotas-user.robot

Wait For Quotas Service Ready
    [Documentation]    Poll a service until OSCAR reports that it can be invoked.
    [Arguments]    ${service_name}
    Wait Until Keyword Succeeds    120s    ${FAST_RETRY_INTERVAL}    Quotas Service Should Be Ready    ${service_name}

Quotas Service Should Be Ready
    [Documentation]    Assert service readiness for the given service name.
    [Arguments]    ${service_name}
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=200
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${status}=    Evaluate    (lambda d: d.get('status') if not isinstance(d.get('status'), dict) else d['status'].get('state') or d['status'].get('phase') or d['status'].get('condition'))(${payload})    json
    ${ready}=    Evaluate    str(${status}).lower() in ("ready","running","available","succeeded") or bool(${payload}.get('ready')) or bool(${payload}.get('token'))
    Should Be True    ${ready}    Service ${service_name} not ready yet (status=${status})

Get Invocation Headers
    [Documentation]    Return headers for direct service invocation, respecting local testing auth.
    ${headers}=    Run Keyword If    '${LOCAL_TESTING}'=='True'    Set Variable    ${HEADERS_OSCAR}    ELSE    Set Variable    ${HEADERS}
    RETURN    ${headers}

POST Run With Short Timeout
    [Documentation]    Invoke /run with a bounded client timeout so readiness failures do not wait for ingress 504.
    [Arguments]    ${service_name}    ${body}
    ${response}=    POST Run With Timeout    ${service_name}    ${body}    ${RUN_REQUEST_TIMEOUT}
    RETURN    ${response}

POST Run With Timeout
    [Documentation]    Invoke /run with a caller-provided client timeout.
    [Arguments]    ${service_name}    ${body}    ${timeout}
    ${headers}=    Get Invocation Headers
    ${response}=    POST    url=${OSCAR_ENDPOINT}/run/${service_name}    expected_status=ANY    verify=${SSL_VERIFY}    headers=&{headers}    data=${body}    timeout=${timeout}
    RETURN    ${response}

Sync Invocation Should Contain Hello
    [Documentation]    Invoke a synchronous service and assert the expected response.
    [Arguments]    ${service_name}    ${body}
    ${resp}=    POST Run With Short Timeout    ${service_name}    ${body}
    Log    Sync response ${service_name}: status=${resp.status_code}, body=${resp.text}
    Should Be Equal As Strings    ${resp.status_code}    200
    Should Contain    ${resp.text}    Hello

Sync Invocation Should Be Rejected By Kueue
    [Documentation]    Invoke an oversized synchronous service and assert the backend rejects it after bounded Kueue admission wait.
    [Arguments]    ${service_name}    ${body}
    ${resp}=    POST With Defaults      url=${OSCAR_ENDPOINT}/run/${service_name}     headers=${HEADERS}     data=${body}
    Log    Sync rejection response ${service_name}: status=${resp.status_code}, body=${resp.text}
    Should Be True    '${resp.status_code}' == '400' or '${resp.status_code}' == '504'

Service Resources Should Exceed Quotas
    [Documentation]    Assert that an oversized service asks for more CPU or memory than the current user quota.
    [Arguments]    ${service_body}
    ${service}=    Evaluate    json.loads($service_body)    json
    ${quota_resp}=    Fetch Quotas Response
    ${quota_json}=    Evaluate    json.loads($quota_resp.content)    json
    ${cpu_res}=    Get From Dictionary    ${quota_json["resources"]}    cpu
    ${mem_res}=    Get From Dictionary    ${quota_json["resources"]}    memory
    ${cpu_max}=    Get From Dictionary    ${cpu_res}    max
    ${mem_max}=    Get From Dictionary    ${mem_res}    max
    ${quota_cpu}=    Parse CPU Quantity To Float    ${cpu_max}
    ${quota_mem}=    Parse Memory Quantity To Mib    ${mem_max}
    ${service_cpu}=    Parse CPU Quantity To Float    ${service["cpu"]}
    ${service_mem}=    Parse Memory Quantity To Mib    ${service["memory"]}
    ${exceeds}=    Evaluate    ${service_cpu} > ${quota_cpu} or ${service_mem} > ${quota_mem}
    Should Be True    ${exceeds}    Service resources cpu=${service_cpu}, memory=${service_mem}Mi do not exceed quota cpu=${quota_cpu}, memory=${quota_mem}Mi

Async Job Should Have Status
    [Documentation]    Poll /system/logs/{service} until at least one job has the expected status.
    [Arguments]    ${service_name}    ${expected_status}
    ${list_jobs}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${service_name}    expected_status=ANY
    Should Be Equal As Strings    ${list_jobs.status_code}    200
    ${job_status}=    Check Job Status    ${list_jobs}
    Log    Async status ${service_name}: ${job_status}
    Should Be Equal As Strings    ${job_status}    ${expected_status}

Exposed Service Should Contain Nginx
    [Documentation]    Poll an exposed service endpoint until nginx responds.
    [Arguments]    ${service_name}
    ${headers}=    Get Invocation Headers
    ${response}=    GET    expected_status=ANY    url=${OSCAR_ENDPOINT}/system/services/${service_name}/exposed    verify=${SSL_VERIFY}    headers=&{headers}    timeout=${RUN_REQUEST_TIMEOUT}
    Log    Exposed response ${service_name}: status=${response.status_code}, body=${response.text}
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.text}    Welcome to nginx

Compute Available CPU
    [Documentation]    Compute available CPU as max - used.
    [Arguments]    ${max_cpu}    ${used_cpu}
    ${max_val}=    Parse CPU Quantity To Float    ${max_cpu}
    ${used_val}=   Parse CPU Quantity To Float    ${used_cpu}
    ${available}=  Evaluate    max(${max_val} - ${used_val}, 0)
    RETURN    ${available}

Parse CPU Quantity To Float
    [Documentation]    Convert CPU quantities to cores. Quota API numeric values are millicores; service values are cores.
    [Arguments]    ${quantity}
    ${quantity}=    Set Variable If    '${quantity}' == 'None' or '${quantity}' == ''    0    ${quantity}
    ${value}=    Evaluate    (lambda q: (lambda s: float(s[:-1]) / 1000 if s.endswith('m') else (float(s) / 1000 if re.fullmatch(r'[0-9]+(\\.[0-9]+)?', s) and float(s) > 100 else float(s)))(str(q)))($quantity)    re
    RETURN    ${value}

Compute Parallel Limit
    [Documentation]    Return how many jobs fit in parallel based on available CPU and service CPU.
    [Arguments]    ${available_cpu}    ${service_cpu}
    ${parallel}=    Evaluate    int(${available_cpu} // ${service_cpu})
    RETURN    ${parallel}

Prepare Sleep Service File
    [Documentation]    Load the sleep-test example, adjust VO/name/paths, and save JSON payload for the API.
    Prepare Sleep Service File With Overrides    ${SERVICE_NAME}    ${EMPTY}    ${DATA_DIR}/service_file.json

Load Sleep Service File
    [Documentation]    Load sleep-test YAML replacing tabs to avoid parsing errors.
    ${yaml_raw}=    Get File    ${SLEEP_SERVICE_FILE}
    ${yaml_clean}=    Replace String    ${yaml_raw}    \t    ${SPACE}${SPACE}${SPACE}${SPACE}
    RETURN    ${yaml_clean}

Prepare Sleep Service File With Overrides
    [Documentation]    Generic helper to adjust name/paths/script and optional memory override.
    [Arguments]    ${target_name}    ${memory_override}    ${output_file}
    ${service_content}=    Load Sleep Service File
    ${service_content}=    Set Service File VO    ${service_content}
    ${script_content}=     Get File    ${SLEEP_SCRIPT_FILE}
    ${service_content}=    Set Service File Script    ${service_content}    ${script_content}

    ${oscar_list}=    Get From Dictionary    ${service_content}[functions]    oscar
    ${first_service_item}=    Get From List    ${oscar_list}    0
    ${service_key_list}=    Get Dictionary Keys    ${first_service_item}
    ${service_key}=    Get From List    ${service_key_list}    0
    ${service_def}=    Get From Dictionary    ${first_service_item}    ${service_key}

    Set To Dictionary    ${service_def}    name=${target_name}
    ${input_entries}=    Get From Dictionary    ${service_def}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${target_name}/input
    ${output_entries}=    Get From Dictionary    ${service_def}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${target_name}/output
    Run Keyword If    '${memory_override}' != ''    Set To Dictionary    ${service_def}    memory=${memory_override}

    ${service_content_json}=    Evaluate    json.dumps(${service_def})    json
    Create File    ${output_file}    ${service_content_json}

Track Job Concurrency Until Done
    [Documentation]    Poll /system/logs/{service} until all jobs finish; return max running and completed count.
    [Arguments]    ${service_name}    ${expected_jobs}    ${headers}=${HEADERS}
    ${max_running}=    Set Variable    0
    ${completed}=      Set Variable    0
    FOR    ${i}    IN RANGE    ${MAX_RETRIES}
        ${logs_resp}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${service_name}    headers=${headers}
        ${jobs_json}=    Evaluate    json.loads($logs_resp.content)    json
        ${jobs_map}=     Get From Dictionary    ${jobs_json}    jobs
        ${statuses}=     Create List
        FOR    ${job_name}    ${info}    IN    &{jobs_map}
            ${status}=    Get From Dictionary    ${info}    status
            Append To List    ${statuses}    ${status}
        END
        ${running_count}=    Count Status Occurrences    ${statuses}    Running
        ${max_running}=      Evaluate    max(${max_running}, ${running_count})
        ${completed}=        Count Completed Statuses    ${statuses}
        Exit For Loop If    ${completed} >= ${expected_jobs}
        Sleep    ${RETRY_INTERVAL}
    END
    RETURN    ${max_running}    ${completed}

Count Status Occurrences
    [Documentation]    Count how many times a status appears in the list.
    [Arguments]    ${statuses}    ${needle}
    ${count}=    Evaluate    sum(1 for s in ${statuses} if s == '${needle}')
    RETURN    ${count}

Count Completed Statuses
    [Documentation]    Count finished jobs (Succeeded or Failed).
    [Arguments]    ${statuses}
    ${count}=    Evaluate    sum(1 for s in ${statuses} if s in ('Succeeded','Failed'))
    RETURN    ${count}

Parse Memory Quantity To Mib
    [Documentation]    Convert memory quantities to MiB. Quota API numeric values are bytes; service values use units.
    [Arguments]    ${quantity}
    ${qstr}=    Set Variable If    '${quantity}' == 'None' or '${quantity}' == ''    0Mi    ${quantity}
    ${value}=    Evaluate    (lambda q: (lambda s: float(s) / 1048576 if re.fullmatch(r'[0-9]+(\\.[0-9]+)?', s) and float(s) > 1048576 else (lambda m: float(m.group(1)) * {'ki':1/1024,'mi':1,'gi':1024,'ti':1048576}.get((m.group(2) or 'mi').lower(),1))(re.match(r'([0-9.]+)([A-Za-z]+)?', s)))(str(q)))($qstr)    re
    RETURN    ${value}


Update User Memory Quota
    [Documentation]    Update user memory quota (MiB) via admin/basic auth.
    [Arguments]    ${memory_mib}
    ${mem_str}=    Evaluate    f"{int(${memory_mib})}Mi"
    ${payload}=    Evaluate    __import__('json').dumps({"memory": "${mem_str}"})
    ${resp}=    PUT With Defaults    url=${OSCAR_ENDPOINT}/system/quotas/user/${USER}    data=${payload}    expected_status=200    headers=${HEADERS_OSCAR}
    Log    ${resp.content}

Update User CPU Quota
    [Documentation]    Update user CPU quota (cores) via admin/basic auth.
    [Arguments]    ${cpu_cores}
    ${cpu_str}=    Evaluate    str(float(${cpu_cores}))
    ${payload}=    Evaluate    __import__('json').dumps({"cpu": "${cpu_str}"})
    ${resp}=    PUT With Defaults    url=${OSCAR_ENDPOINT}/system/quotas/user/${USER}    data=${payload}    expected_status=200    headers=${HEADERS_OSCAR}
    Log    ${resp.content}

Cleanup Quotas Services
    [Documentation]    Remove jobs and services created by this suite, and delete temporary files.
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}?all=true
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    Run Keyword And Ignore Error    Cleanup Generated Service    sync-correct-resources-${RANDOM_STRING}
    Run Keyword And Ignore Error    Cleanup Generated Service    sync-insufficient-${RANDOM_STRING}
    Run Keyword And Ignore Error    Cleanup Generated Service    async-correct-resources-${RANDOM_STRING}
    Run Keyword And Ignore Error    Cleanup Generated Service    async-insufficient-${RANDOM_STRING}
    Run Keyword And Ignore Error    Cleanup Generated Service    exposed-correct-${RANDOM_STRING}
    Run Keyword And Ignore Error    Cleanup Generated Service    exposed-insufficient-${RANDOM_STRING}
    Run Keyword And Ignore Error    Clean Test Artifacts    ${DATA_DIR}/service_file.json
    Run Keyword And Ignore Error    Clean Test Artifacts    ${DATA_DIR}/exposed_service_file.json

Cleanup Generated Service
    [Documentation]    Delete logs and service for one generated service name.
    [Arguments]    ${service_name}
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${service_name}?all=true    expected_status=ANY
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=ANY

Restore User Memory Quota
    [Documentation]    Restore memory quota to original value if it was captured.
    Run Keyword If    ${ORIG_MEM_MAX_MI} > 0    Update User Memory Quota    ${ORIG_MEM_MAX_MI}
    Run Keyword If    ${ORIG_CPU_CORES} > 0    Update User CPU Quota    ${ORIG_CPU_CORES}

Prepare Service File With Correct Resources
    [Documentation]    Prepare service configuration with adequate resources
    [Arguments]    ${service_name}
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Set Service File VO    ${service_content}
    
    VAR    ${modified_content}=    ${service_content}[functions][oscar][0][robot-oscar-cluster]
    
    ${script_value}=    Catenate
    ...    \#!/bin/sh\n\necho "Hello from ${service_name}"\n\
    Set To Dictionary    ${modified_content}    script=${script_value}
    Set To Dictionary    ${modified_content}    name=${service_name}
    Set To Dictionary    ${modified_content}    cpu=0.5
    Set To Dictionary    ${modified_content}    memory=256Mi
    
    ${input_entries}=    Get From Dictionary    ${modified_content}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${service_name}/input
    
    ${output_entries}=    Get From Dictionary    ${modified_content}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${service_name}/output
    
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${DATA_DIR}/service_file.json    ${service_content_json}

Prepare Service File With Insufficient Resources
    [Documentation]    Prepare service configuration with inadequate resources
    [Arguments]    ${service_name}
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Set Service File VO    ${service_content}
    
    VAR    ${modified_content}=    ${service_content}[functions][oscar][0][robot-oscar-cluster]
    
    ${script_value}=    Catenate
    ...    \#!/bin/sh\n\nsleep 30\necho "Hello from ${service_name}"\n\
    Set To Dictionary    ${modified_content}    script=${script_value}
    Set To Dictionary    ${modified_content}    name=${service_name}
    Set To Dictionary    ${modified_content}    cpu=10.0
    Set To Dictionary    ${modified_content}    memory=32Gi
    
    ${input_entries}=    Get From Dictionary    ${modified_content}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${service_name}/input
    
    ${output_entries}=    Get From Dictionary    ${modified_content}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${service_name}/output
    
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${DATA_DIR}/service_file.json    ${service_content_json}

Prepare Exposed Service With Correct Resources
    [Documentation]    Prepare exposed service configuration with adequate resources
    [Arguments]    ${service_name}
    ${service_content}=    Get File    ${DATA_DIR}/expose_services/nginx_expose.yaml
    ${service_content}=    Set Service File VO    ${service_content}
    ${script_content}=    Get File    ${NGINX_SCRIPT_FILE}
    ${service_content}=    Set Service File Script    ${service_content}    ${script_content}

    VAR    ${modified_content}=    ${service_content}[functions][oscar][0][oscar-cluster]
    Set To Dictionary    ${modified_content}    name=${service_name}
    Set To Dictionary    ${modified_content}    cpu=0.5
    Set To Dictionary    ${modified_content}    memory=256Mi
    
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${DATA_DIR}/exposed_service_file.json    ${service_content_json}

Prepare Exposed Service With Insufficient Resources
    [Documentation]    Prepare exposed service configuration with inadequate resources
    [Arguments]    ${service_name}
    ${service_content}=    Get File    ${DATA_DIR}/expose_services/nginx_expose.yaml
    ${service_content}=    Set Service File VO    ${service_content}
    ${script_content}=    Get File    ${NGINX_SCRIPT_FILE}
    ${service_content}=    Set Service File Script    ${service_content}    ${script_content}
    
    VAR    ${modified_content}=    ${service_content}[functions][oscar][0][oscar-cluster]
    Set To Dictionary    ${modified_content}    name=${service_name}
    Set To Dictionary    ${modified_content}    cpu=10.0
    Set To Dictionary    ${modified_content}    memory=32Gi
    
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${DATA_DIR}/exposed_service_file.json    ${service_content_json}

Check Job Status
    [Documentation]    Check Job Succeeded from job creation response
    [Arguments]    ${response}
    Run Keyword If    '''${response.content}''' == ''    Fail    Response content is empty despite status ${response.status_code}
    ${response_json}=    Evaluate    json.loads($response.content)    json
    ${jobs}=    Get From Dictionary    ${response_json}    jobs
    ${job_keys}=    Get Dictionary Keys    ${jobs}
    ${first_job_id}=    Set Variable    ${job_keys[0]}
    ${job_data}=    Get From Dictionary    ${jobs}    ${first_job_id}
    ${jobs_status}=    Get From Dictionary    ${job_data}    status
    RETURN    ${jobs_status}
