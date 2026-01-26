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
Suite Teardown      Run Keywords    Restore User Memory Quota    AND    Cleanup Sleep Service


*** Variables ***
${SERVICE_BASE}                 sleep-test
${SERVICE_NAME}                 ${SERVICE_BASE}
${SLEEP_SERVICE_FILE}           ${DATA_DIR}/sleep-test.yaml
${SLEEP_SCRIPT_FILE}            ${DATA_DIR}/sleep-test.sh
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

Create sleep-test service
    [Documentation]    Deploy the sleep-test service with a random name.
    Prepare Sleep Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    # Verify the service can be read to confirm the expected name
    ${read_resp}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    ${read_json}=    Evaluate    json.loads($read_resp.content)    json
    ${read_name}=    Get From Dictionary    ${read_json}    name
    Should Be Equal As Strings    ${read_name}    ${SERVICE_NAME}

Submit jobs and verify concurrency
    [Documentation]    Launch N+2 async jobs and ensure only N (quota) are running.
    Skip If    ${JOB_COUNT} < 2    No jobs were planned (check quotas)
    ${body}=    Get File    ${INVOKE_FILE}
    Log         Submitting ${JOB_COUNT} jobs with resources -> cpu=${SERVICE_CPU}, memory=256Mi (service spec)
    FOR    ${i}    IN RANGE    ${JOB_COUNT}
        ${job_resp}=    POST With Defaults    url=${OSCAR_ENDPOINT}/job/${SERVICE_NAME}    data=${body}
        Should Be Equal As Strings    ${job_resp.status_code}    201
    END
    ${max_running}    ${completed_jobs}=    Track Job Concurrency Until Done    ${SERVICE_NAME}    ${JOB_COUNT}    ${HEADERS_OSCAR}
    Set Suite Variable    ${MAX_RUNNING_SEEN}    ${max_running}
    Should Be Equal As Integers    ${max_running}    ${PARALLEL_LIMIT}    msg=Expected to cap at quota (${PARALLEL_LIMIT}) concurrent jobs
    Should Be Equal As Integers    ${completed_jobs}    ${JOB_COUNT}

Increase CPU quota allows one more job
    [Documentation]    Increase CPU quota slightly and verify one more job can run concurrently.
    ${new_cpu_cores}=    Evaluate    ${ORIG_CPU_CORES} + ${SERVICE_CPU}
    Update User CPU Quota    ${new_cpu_cores}
    ${quota_check}=    Fetch Quotas Response
    ${quota_json}=    Evaluate    json.loads($quota_check.content)    json
    ${cpu_res}=    Get From Dictionary    ${quota_json["resources"]}    cpu
    ${cpu_max}=    Get From Dictionary    ${cpu_res}    max
    ${cpu_max_cores}=    Parse CPU Quantity To Float    ${cpu_max}
    Log         Updated CPU quota: max=${cpu_max} (${cpu_max_cores} cores)
    Run Keyword If    ${cpu_max_cores} <= ${ORIG_CPU_CORES}    Fail    CPU quota did not increase (old=${ORIG_CPU_CORES}, new=${cpu_max_cores})
    Set Suite Variable    ${NEW_CPU_CORES}    ${cpu_max_cores}
    ${new_parallel}=    Compute Parallel Limit    ${cpu_max_cores}    ${SERVICE_CPU}
    ${job_count}=    Evaluate    ${new_parallel} + 1
    Log         Submitting ${job_count} jobs after CPU increase; expect max running >= ${PARALLEL_LIMIT + 1}
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}?all=true
    ${body}=    Get File    ${INVOKE_FILE}
    FOR    ${i}    IN RANGE    ${job_count}
        ${job_resp}=    POST With Defaults    url=${OSCAR_ENDPOINT}/job/${SERVICE_NAME}    data=${body}
        Should Be Equal As Strings    ${job_resp.status_code}    201
    END
    ${max_running}    ${completed_jobs}=    Track Job Concurrency Until Done    ${SERVICE_NAME}    ${job_count}    ${HEADERS_OSCAR}
    Should Be True    ${max_running} >= ${PARALLEL_LIMIT + 1}    msg=Expected at least one more concurrent job after quota increase
    Should Be Equal As Integers    ${completed_jobs}    ${job_count}

Delete sleep-test service
    [Documentation]    Delete the sleep-test service with a random name.
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    Should Be Equal As Strings    ${response.status_code}    204

Execute Synchronous Calls With Correct Resources
    [Documentation]    Test synchronous service calls with adequate resources for successful execution
    [Tags]    sync    correct-resources
    ${service_name}=    Set Variable    sync-correct-resources-${RANDOM_STRING}
    Prepare Service File With Correct Resources    ${service_name}
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    ${invoke_body}=    Get File    ${INVOKE_FILE}
    FOR    ${j}    IN RANGE    ${MAX_RETRIES}
        ${status}    ${resp}=    Run Keyword And Ignore Error    POST    url=${OSCAR_ENDPOINT}/run/${service_name}      headers=${HEADERS}       data=${invoke_body}
        IF    '${status}' != 'FAIL'
            Log     ${status} 
            Log     ${resp.content}
            ${status}=    Run Keyword And Return Status    Should Contain    ${resp.content}    Hello
            Exit For Loop If    ${status}
        END
        Sleep   ${RETRY_INTERVAL}
    END
    Log    Exited
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}
    Should Be Equal As Strings    ${response.status_code}    204

Execute Synchronous Calls With Insufficient Resources
    [Documentation]    Test synchronous service calls with inadequate resources expecting failure or timeout
    [Tags]    sync    insufficient-resources
    ${service_name}=    Set Variable    sync-insufficient-${RANDOM_STRING}
    Prepare Service File With Insufficient Resources    ${service_name}
    ${body}=    Get File    ${DATA_DIR}/service_file.json

    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    ${invoke_body}=    Get File    ${INVOKE_FILE}
    FOR    ${j}    IN RANGE    ${MAX_RETRIES}
        ${resp}=       POST    url=${OSCAR_ENDPOINT}/run/${service_name}        expected_status=ANY      headers=${HEADERS}       data=${invoke_body}
        Exit For Loop If    '${resp.status_code}' == '400'
        Sleep   ${RETRY_INTERVAL}
    END
    Log    Exited
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}
    Should Be Equal As Strings    ${response.status_code}    204

Execute Asynchronous Calls With Correct Resources
    [Documentation]    Test asynchronous service calls with adequate resources for successful execution
    [Tags]    async    correct-resources
    ${service_name}=    Set Variable    async-correct-resources-${RANDOM_STRING}
    Prepare Service File With Correct Resources    ${service_name}
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    ${invoke_body}=    Get File    ${INVOKE_FILE}
    ${job_response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/job/${service_name}    data=${invoke_body}
    Should Be Equal As Strings    ${job_response.status_code}    201
    FOR    ${j}    IN RANGE    ${MAX_RETRIES}
        ${list_jobs}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}
        ${job_status}=    Check Job Status    ${list_jobs}
        Log     ${job_status}
        Exit For Loop If        '${job_status}' == 'Succeeded'
        Sleep   ${RETRY_INTERVAL}
    END
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}
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
    FOR    ${j}    IN RANGE    ${MAX_RETRIES}
        ${list_jobs}=    GET    expected_status=ANY   url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}     headers=${HEADERS}
        ${job_status}=    Check Job Status    ${list_jobs}
        Exit For Loop If        '${job_status}' == 'Suspended'
        Sleep   ${RETRY_INTERVAL}
    END
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}
    Should Be Equal As Strings    ${response.status_code}    204

Execute Exposed Service With Correct Resources
    [Documentation]    Test exposed service calls with adequate resources for successful execution
    [Tags]    exposed    correct-resources
    ${service_name}=    Set Variable    exposed-correct-${RANDOM_STRING}
    Prepare Exposed Service With Correct Resources    ${service_name}
    ${body}=    Get File    ${DATA_DIR}/exposed_service_file.json
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    FOR    ${j}    IN RANGE    ${MAX_RETRIES}
        ${response}=    GET     expected_status=ANY     url=${OSCAR_ENDPOINT}/system/services/${service_name}/exposed       headers=${HEADERS}
        ${contains_nginx}=    Run Keyword And Return Status    Should Contain    ${response.content}    Welcome to nginx
        Exit For Loop If    ${contains_nginx}
        Sleep   ${RETRY_INTERVAL}
    END
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}
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

Compute Available CPU
    [Documentation]    Compute available CPU as max - used.
    [Arguments]    ${max_cpu}    ${used_cpu}
    ${max_val}=    Parse CPU Quantity To Float    ${max_cpu}
    ${used_val}=   Parse CPU Quantity To Float    ${used_cpu}
    ${available}=  Evaluate    max(${max_val} - ${used_val}, 0)
    RETURN    ${available}

Parse CPU Quantity To Float
    [Documentation]    Convert CPU quantities (e.g., 500m, 2) to float cores.
    [Arguments]    ${quantity}
    ${quantity}=    Set Variable If    '${quantity}' == 'None' or '${quantity}' == ''    0    ${quantity}
    ${value}=    Evaluate    (lambda q: float(q[:-1])/1000 if str(q).endswith('m') else float(q))(${quantity})
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
    [Documentation]    Convert memory quantities (e.g., 256Mi, 1Gi) to MiB as float.
    [Arguments]    ${quantity}
    ${qstr}=    Set Variable If    '${quantity}' == 'None' or '${quantity}' == ''    0Mi    ${quantity}
    ${value}=    Evaluate    (lambda q: (lambda m: float(m.group(1)) * {'ki':1/1024,'mi':1,'gi':1024,'ti':1048576}.get((m.group(2) or 'mi').lower(),1))(re.match(r'([0-9.]+)([A-Za-z]+)?', str(q))))('${qstr}')    re
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

Cleanup Sleep Service
    [Documentation]    Remove jobs and service if present, and delete temporary files.
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}?all=true
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    Run Keyword And Ignore Error    Clean Test Artifacts    ${DATA_DIR}/service_file.json
    Run Keyword And Ignore Error    Clean Test Artifacts    ${DATA_DIR}/exposed_service_file.json

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