*** Settings ***
Documentation       Opt-in, two-cluster job delegation. The first cluster is the origin; the second is the destination. Does not change quotas.
Library             Collections
Library             OperatingSystem
Library             RequestsLibrary
Library             String
Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Suite Setup         Initialize Delegation Environment
Test Setup          Prepare Delegation Fixture
Test Teardown       Cleanup Delegation Fixture

*** Variables ***
${DELEGATION_CPU}       0.5
${DELEGATION_MEMORY}    256Mi
${DELEGATION_IMAGE}     ubuntu:22.04
${DELEGATION_TIMEOUT}   180s
${MINIO_TEST_ENDPOINT}   ${EMPTY}
${KEEP_SERVICES}        ${False}
${FIXTURE_ATTEMPTED}   ${False}
${JOB_ID}              ${EMPTY}

*** Test Cases ***
Job Executes On Destination Only
    [Documentation]    POST to the origin must produce a succeeded Job and marker on the destination, not a local Job.
    ${local}=    Get Jobs    ${ORIGIN_ENDPOINT}    ${ORIGIN_NAME}    ${ORIGIN_VERIFY}
    ${remote}=    Get Jobs    ${TARGET_ENDPOINT}    ${WORKER_NAME}    ${TARGET_VERIFY}
    Should Be Empty    ${local}
    Should Be Empty    ${remote}
    Check Quota Precondition
    Upload Fixture Input
    Check Quota Precondition
    # Delegated MinIO events carry the provider ID "default", not the FDL name "minio.default".
    ${event}=    Evaluate    json.dumps({'storage_provider': 'default', 'event': json.dumps({'Records': [{'eventSource': 'minio:s3', 'eventTime': '2020-01-01T00:00:00Z', 's3': {'bucket': {'name': $ORIGIN_NAME, 'arn': 'arn:aws:s3:::' + $ORIGIN_NAME}, 'object': {'key': $INPUT_KEY}}}]})})    modules=json
    ${response}=    POST    url=${ORIGIN_ENDPOINT}/job/${ORIGIN_NAME}
    ...    data=${event}    headers=${HEADERS}    expected_status=ANY    verify=${ORIGIN_VERIFY}
    Should Be Equal As Integers    ${response.status_code}    201
    Wait Until Keyword Succeeds    ${DELEGATION_TIMEOUT}    5s    Delegated Job Should Succeed
    ${response}=    GET    url=${TARGET_ENDPOINT}/system/logs/${WORKER_NAME}/${JOB_ID}
    ...    headers=${HEADERS}    expected_status=200    verify=${TARGET_VERIFY}
    Should Be True    $MARKER in $response.text    Destination Job logs lack test marker
    Input Object Should Match Fixture
    Wait Until Keyword Succeeds    ${DELEGATION_TIMEOUT}    5s    Processed Output Should Match Input
    ${local}=    Get Jobs    ${ORIGIN_ENDPOINT}    ${ORIGIN_NAME}    ${ORIGIN_VERIFY}
    Should Be Empty    ${local}

Bucket Upload Triggers Delegated Job
    [Documentation]    A MinIO notification from the origin input prefix must produce exactly one destination Job without an explicit /job POST.
    ${local}=    Get Jobs    ${ORIGIN_ENDPOINT}    ${ORIGIN_NAME}    ${ORIGIN_VERIFY}
    ${remote}=    Get Jobs    ${TARGET_ENDPOINT}    ${WORKER_NAME}    ${TARGET_VERIFY}
    Should Be Empty    ${local}
    Should Be Empty    ${remote}
    Check Quota Precondition
    Set Test Variable    ${INPUT_KEY}    input/${MARKER}.txt
    # The PUT may trigger a Job before it returns; teardown cancels test-owned Jobs unless KEEP_SERVICES is enabled.
    Upload Fixture Input As OIDC User
    Wait Until Keyword Succeeds    ${DELEGATION_TIMEOUT}    5s    Delegated Job Should Succeed
    ${response}=    GET    url=${TARGET_ENDPOINT}/system/logs/${WORKER_NAME}/${JOB_ID}
    ...    headers=${HEADERS}    expected_status=200    verify=${TARGET_VERIFY}
    Should Be True    $MARKER in $response.text    Destination Job logs lack test marker
    Input Object Should Match Fixture
    Wait Until Keyword Succeeds    ${DELEGATION_TIMEOUT}    5s    Processed Output Should Match Input
    ${local}=    Get Jobs    ${ORIGIN_ENDPOINT}    ${ORIGIN_NAME}    ${ORIGIN_VERIFY}
    Should Be Empty    ${local}
    ${remote}=    Get Jobs    ${TARGET_ENDPOINT}    ${WORKER_NAME}    ${TARGET_VERIFY}
    Length Should Be    ${remote}    1    Notification must produce exactly one destination Job

*** Keywords ***
Initialize Delegation Environment
    # Suppress keyword messages that may include OIDC credentials or service tokens.
    Set Log Level    WARN
    ${target_file}=    Get Variable Value    \${TARGET_CLUSTER_CONFIG}    ${EMPTY}
    Skip If    not $target_file    Two-cluster suite requires an explicit target cluster
    ${yaml}=    Get File    ${target_file}
    ${target_config}=    Evaluate    yaml.safe_load($yaml)    modules=yaml
    ${source}=    Evaluate    str($OSCAR_ENDPOINT).rstrip('/')
    ${target}=    Evaluate    str($target_config['OSCAR_ENDPOINT']).rstrip('/')
    Should Not Be Equal As Strings    ${source}    ${target}    Origin and destination endpoints must differ
    Set Suite Variable    ${ORIGIN_ENDPOINT}    ${source}
    Set Suite Variable    ${TARGET_ENDPOINT}    ${target}
    ${source_federation}=    Get Variable Value    \${OSCAR_FEDERATION_ENDPOINT}    ${source}
    ${target_federation}=    Evaluate    str($target_config.get('OSCAR_FEDERATION_ENDPOINT') or $target).rstrip('/')
    Should Not Be Equal As Strings    ${source_federation}    ${target_federation}    Federation endpoints must differ
    Set Suite Variable    ${ORIGIN_FEDERATION_ENDPOINT}    ${source_federation}
    Set Suite Variable    ${TARGET_FEDERATION_ENDPOINT}    ${target_federation}
    ${source_verify}=    Convert To Boolean    ${SSL_VERIFY}
    ${target_verify}=    Convert To Boolean    ${target_config}[SSL_VERIFY]
    Set Suite Variable    ${ORIGIN_VERIFY}    ${source_verify}
    Set Suite Variable    ${TARGET_VERIFY}    ${target_verify}
    Check Valid OIDC Token
    Set Refresh Token
    Set Suite Variable    ${BASE_DELEGATION_CPU}    ${DELEGATION_CPU}
    Set Suite Variable    ${BASE_DELEGATION_MEMORY}    ${DELEGATION_MEMORY}

Prepare Delegation Fixture
    Set Suite Variable    ${FIXTURE_ATTEMPTED}    ${False}
    Set Suite Variable    ${JOB_ID}    ${EMPTY}
    # Kueue quota usage can lag the previous test's cleanup; do not create a fixture until it clears.
    Wait Until Keyword Succeeds    120s    5s    Select Delegation Resources
    ${suffix}=    Generate Random String    10    [LOWER][NUMBERS]
    Set Suite Variable    ${ORIGIN_NAME}    robot-delegation-origin-${suffix}
    Set Suite Variable    ${WORKER_NAME}    robot-delegation-worker-${suffix}
    Set Suite Variable    ${MARKER}    delegated-${suffix}
    ${template}=    Get File    ${CURDIR}/service.yaml
    ${template}=    Replace String    ${template}    __ORIGIN_NAME__    ${ORIGIN_NAME}
    ${template}=    Replace String    ${template}    __WORKER_NAME__    ${WORKER_NAME}
    ${template}=    Replace String    ${template}    __ORIGIN_ENDPOINT__    ${ORIGIN_FEDERATION_ENDPOINT}
    ${template}=    Replace String    ${template}    __TARGET_ENDPOINT__    ${TARGET_FEDERATION_ENDPOINT}
    ${template}=    Replace String    ${template}    __ORIGIN_SSL__    ${ORIGIN_VERIFY}
    ${template}=    Replace String    ${template}    __TARGET_SSL__    ${TARGET_VERIFY}
    ${template}=    Replace String    ${template}    __CPU__    ${DELEGATION_CPU}
    ${template}=    Replace String    ${template}    __MEMORY__    ${DELEGATION_MEMORY}
    ${template}=    Replace String    ${template}    __IMAGE__    ${DELEGATION_IMAGE}
    ${fdl}=    Evaluate    yaml.safe_load($template)    modules=yaml
    ${service}=    Evaluate    next(iter($fdl['functions']['oscar'][0].values()))
    ${script}=    Get File    ${CURDIR}/script.sh
    ${script}=    Replace String    ${script}    __MARKER__    ${MARKER}
    Set To Dictionary    ${service}    script=${script}    cluster_id=origin    clusters=${fdl}[clusters]
    ${minio_endpoint}=    Get Variable Value    \${OSCAR_FEDERATION_MINIO_ENDPOINT}    ${EMPTY}
    IF    $minio_endpoint
        ${providers}=    Evaluate    {'minio': {'default': {'endpoint': $minio_endpoint, 'verify': False}}}
        Set To Dictionary    ${service}    storage_providers=${providers}
    END
    ${host_minio}=    Set Variable    ${MINIO_TEST_ENDPOINT}
    ${is_local}=    Evaluate    urllib.parse.urlsplit($ORIGIN_ENDPOINT).hostname in ('localhost', 'localhost.direct', '127.0.0.1')    modules=urllib.parse
    IF    not $host_minio and $is_local and $minio_endpoint
        ${host_minio}=    Evaluate    urllib.parse.urlsplit($minio_endpoint)._replace(netloc='localhost:' + str(urllib.parse.urlsplit($minio_endpoint).port)).geturl()    modules=urllib.parse
    END
    Set Suite Variable    ${HOST_MINIO_ENDPOINT}    ${host_minio}
    Set Suite Variable    ${INPUT_KEY}    fixtures/${MARKER}.txt
    Set Suite Variable    ${OUTPUT_KEY}    output/${MARKER}-out.txt
    Set Suite Variable    ${INPUT_TEXT}    ${MARKER} alpha beta\nline two words\n
    Set To Dictionary    ${service}[environment][secrets]    refresh_token=${REFRESH_TOKEN}
    ${body}=    Evaluate    json.dumps($service)    modules=json
    # Names are unique; never delete a service that existed before this invocation.
    Service Must Not Exist    ${ORIGIN_ENDPOINT}    ${ORIGIN_NAME}    ${ORIGIN_VERIFY}
    Service Must Not Exist    ${TARGET_ENDPOINT}    ${WORKER_NAME}    ${TARGET_VERIFY}
    Set Suite Variable    ${FIXTURE_ATTEMPTED}    ${True}
    ${response}=    POST    url=${ORIGIN_ENDPOINT}/system/services
    ...    data=${body}    headers=${HEADERS}    expected_status=ANY    verify=${ORIGIN_VERIFY}
    IF    $response.status_code != 201
        ${detail}=    Evaluate    re.sub(r'(?i)(bearer|basic|token|password|secret)\s*[:= ]\s*[^\s,;]+', r'\1 [REDACTED]', $response.text)[:500]    modules=re
        Fail    Origin service creation HTTP ${response.status_code}: ${detail}
    END
    Wait Until Keyword Succeeds    120s    5s    Service Must Exist    ${TARGET_ENDPOINT}    ${WORKER_NAME}    ${TARGET_VERIFY}
    Service Must Exist    ${ORIGIN_ENDPOINT}    ${ORIGIN_NAME}    ${ORIGIN_VERIFY}
    # The origin service must deploy ready: its running Knative instance holds the
    # reservation that keeps the Job from being admitted locally, so delegation has a
    # deterministic trigger and a failed origin deployment fails the test.
    Wait Until Keyword Succeeds    120s    5s    Deployment Should Be Ready    ${ORIGIN_ENDPOINT}    ${ORIGIN_NAME}    ${ORIGIN_VERIFY}

Select Delegation Resources
    [Documentation]    Choose a request that fits the origin's free quota with headroom so its Knative instance deploys, yet cannot be admitted a second time next to that running instance, so the Job delegates; no quota or load is changed.
    Set Suite Variable    ${DELEGATION_CPU}    ${BASE_DELEGATION_CPU}
    Set Suite Variable    ${DELEGATION_MEMORY}    ${BASE_DELEGATION_MEMORY}
    Should Match Regexp    ${DELEGATION_MEMORY}    ^[1-9][0-9]*Mi$
    ${minimum_cpu}=    Evaluate    round(float($DELEGATION_CPU) * 1000)
    ${minimum_memory}=    Evaluate    int($DELEGATION_MEMORY[:-2]) * 1048576
    Should Be True    ${minimum_cpu} > 0
    ${origin}    ${target}=    Read Quota Resources
    # OSCAR treats either zero maximum as unrestricted and will not delegate for quota reasons.
    Should Be True    $origin['cpu']['max'] > 0 and $origin['memory']['max'] > 0
    ...    Origin has an unrestricted quota; cannot force quota-based delegation
    ${free_cpu}=    Evaluate    max(0, $origin['cpu']['max'] - $origin['cpu']['used'])
    ${free_memory}=    Evaluate    max(0, $origin['memory']['max'] - $origin['memory']['used'])
    # The worker service and its Job can each reserve the requested resources on the destination.
    ${target_cpu}=    Evaluate    float('inf') if $target['cpu']['max'] == 0 else max(0, ($target['cpu']['max'] - $target['cpu']['used']) // 2)
    ${target_memory}=    Evaluate    float('inf') if $target['memory']['max'] == 0 else max(0, ($target['memory']['max'] - $target['memory']['used']) // 2)
    # Occupy three quarters of the origin's free quota on one dimension: the service's own
    # Knative instance deploys with headroom, but a second reservation of the same size
    # (the Job) cannot be admitted next to it, which is what forces delegation.
    ${cpu_request}=    Evaluate    max($minimum_cpu, (3 * $free_cpu) // 4)
    ${memory_request}=    Evaluate    max($minimum_memory, (3 * $free_memory) // (4 * 1048576) * 1048576)
    IF    $cpu_request <= $free_cpu and $minimum_memory <= $free_memory and $cpu_request <= $target_cpu and $minimum_memory <= $target_memory
        ${selected_cpu}=    Evaluate    str($cpu_request / 1000)
        Set Suite Variable    ${DELEGATION_CPU}    ${selected_cpu}
    ELSE IF    $minimum_cpu <= $free_cpu and $memory_request <= $free_memory and $minimum_cpu <= $target_cpu and $memory_request <= $target_memory
        ${selected_memory}=    Evaluate    str($memory_request // 1048576) + 'Mi'
        Set Suite Variable    ${DELEGATION_MEMORY}    ${selected_memory}
    ELSE
        Fail    No request fits the origin with headroom and two destination reservations; no resources were created
    END
    Log To Console    Delegation request: ${DELEGATION_CPU} CPU, ${DELEGATION_MEMORY} memory (the Job cannot be admitted next to the service)

Read Quota Resources
    ${source}=    GET    url=${ORIGIN_ENDPOINT}/system/quotas/user
    ...    headers=${HEADERS}    expected_status=200    verify=${ORIGIN_VERIFY}
    ${target}=    GET    url=${TARGET_ENDPOINT}/system/quotas/user
    ...    headers=${HEADERS}    expected_status=200    verify=${TARGET_VERIFY}
    ${origin}=    Evaluate    json.loads($source.content)['resources']    modules=json
    ${destination}=    Evaluate    json.loads($target.content)['resources']    modules=json
    RETURN    ${origin}    ${destination}

Check Quota Precondition
    ${requested_cpu}=    Evaluate    round(float($DELEGATION_CPU) * 1000)
    ${requested_memory}=    Evaluate    int($DELEGATION_MEMORY[:-2]) * 1048576
    # The origin service's own Knative instance must already hold its reservation before
    # the Job is submitted: quota admission can lag service creation, so wait for the shortage.
    Wait Until Keyword Succeeds    60s    5s    Origin Quota Should Be Short    ${requested_cpu}    ${requested_memory}
    ${source_quota}    ${target_quota}=    Read Quota Resources
    ${target_enough}=    Evaluate
    ...    ($target_quota['cpu']['max'] == 0 or $target_quota['cpu']['max'] - $target_quota['cpu']['used'] >= $requested_cpu) and ($target_quota['memory']['max'] == 0 or $target_quota['memory']['max'] - $target_quota['memory']['used'] >= $requested_memory)
    Should Be True    ${target_enough}    Precondition unmet: destination quota is insufficient

Origin Quota Should Be Short
    [Arguments]    ${requested_cpu}    ${requested_memory}
    ${source_quota}    ${target_quota}=    Read Quota Resources
    ${source_short}=    Evaluate
    ...    $source_quota['cpu']['max'] != 0 and $source_quota['memory']['max'] != 0 and ($source_quota['cpu']['max'] - $source_quota['cpu']['used'] < $requested_cpu or $source_quota['memory']['max'] - $source_quota['memory']['used'] < $requested_memory)
    Should Be True    ${source_short}    Precondition unmet: origin free quota still covers the request; the service's Knative instance may not be holding its reservation

Presign Fixture Object
    [Arguments]    ${key}    ${operation}
    ${body}=    Evaluate    json.dumps({'object_key': $key, 'operation': $operation})    modules=json
    ${response}=    POST    url=${ORIGIN_ENDPOINT}/system/buckets/${ORIGIN_NAME}/presign
    ...    data=${body}    headers=${HEADERS}    expected_status=200    verify=${ORIGIN_VERIFY}
    ${signed}=    Evaluate    json.loads($response.content)    modules=json
    Should Be Equal As Strings    ${signed}[operation]    ${operation}
    ${method}=    Set Variable If    '${operation}' == 'upload'    PUT    GET
    Should Be Equal As Strings    ${signed}[method]    ${method}
    ${parts}=    Evaluate    urllib.parse.urlsplit($signed['url'])    modules=urllib.parse
    ${url}=    Set Variable    ${signed}[url]
    ${headers}=    Evaluate    dict($signed.get('headers') or {})
    IF    $HOST_MINIO_ENDPOINT
        ${proxy}=    Evaluate    urllib.parse.urlsplit($HOST_MINIO_ENDPOINT)    modules=urllib.parse
        ${url}=    Evaluate    $parts._replace(scheme=$proxy.scheme, netloc=$proxy.netloc).geturl()
        Set To Dictionary    ${headers}    Host=${parts.netloc}
    END
    RETURN    ${url}    ${headers}

Upload Fixture Input
    [Documentation]    Upload to the test case's input key; fixtures/ does not trigger, input/ does.
    ${url}    ${headers}=    Presign Fixture Object    ${INPUT_KEY}    upload
    ${response}=    PUT    url=${url}    data=${INPUT_TEXT}
    ...    headers=${headers}    expected_status=ANY    verify=${ORIGIN_VERIFY}
    Should Be Equal As Integers    ${response.status_code}    200
    Input Object Should Match Fixture

Upload Fixture Input As OIDC User
    [Documentation]    Use the OIDC user's MinIO credentials, not OSCAR's admin-signed presign URL, so the notification carries the service owner's identity.
    ${response}=    GET    url=${ORIGIN_ENDPOINT}/system/config
    ...    headers=${HEADERS}    expected_status=200    verify=${ORIGIN_VERIFY}
    ${provider}=    Evaluate    json.loads($response.content)['minio_provider']    modules=json
    Should Be True    bool($provider.get('access_key')) and bool($provider.get('secret_key')) and bool($provider.get('endpoint'))
    ...    OIDC user MinIO credentials are unavailable
    ${endpoint}=    Evaluate    $HOST_MINIO_ENDPOINT or $provider['endpoint']
    ${verify}=    Evaluate    $ORIGIN_VERIFY if $HOST_MINIO_ENDPOINT else $provider['verify']
    ${client}=    Evaluate
    ...    boto3.client('s3', endpoint_url=$endpoint, aws_access_key_id=$provider['access_key'], aws_secret_access_key=$provider['secret_key'], region_name=$provider.get('region', 'us-east-1'), verify=$verify, config=botocore.config.Config(signature_version='s3v4', s3={'addressing_style': 'path'}))
    ...    modules=boto3,botocore.config
    ${upload}=    Evaluate    $client.put_object(Bucket=$ORIGIN_NAME, Key=$INPUT_KEY, Body=$INPUT_TEXT.encode('utf-8'))
    Should Be Equal As Integers    ${upload}[ResponseMetadata][HTTPStatusCode]    200
    Input Object Should Match Fixture

Input Object Should Match Fixture
    ${download_url}    ${download_headers}=    Presign Fixture Object    ${INPUT_KEY}    download
    ${input}=    GET    url=${download_url}    headers=${download_headers}
    ...    expected_status=200    verify=${ORIGIN_VERIFY}
    Should Be Equal As Strings    ${input.text}    ${INPUT_TEXT}    Uploaded fixture differs from its source text

Processed Output Should Match Input
    ${url}    ${headers}=    Presign Fixture Object    ${OUTPUT_KEY}    download
    ${response}=    GET    url=${url}    headers=${headers}    expected_status=ANY    verify=${ORIGIN_VERIFY}
    Should Be Equal As Integers    ${response.status_code}    200    Output object not available yet
    ${expected_words}=    Evaluate    len($INPUT_TEXT.split())
    ${expected_chars}=    Evaluate    len($INPUT_TEXT)
    Should Be True    $response.text.startswith($INPUT_TEXT)    Processed output differs from input text
    Should Be True    'Words: ' + str($expected_words) in $response.text    Output word count differs from input
    Should Be True    'Characters: ' + str($expected_chars) in $response.text    Output character count differs from input

Service Must Not Exist
    [Arguments]    ${endpoint}    ${name}    ${verify}
    ${response}=    GET    url=${endpoint}/system/services/${name}
    ...    headers=${HEADERS}    expected_status=ANY    verify=${verify}
    Should Be Equal As Integers    ${response.status_code}    404

Service Must Exist
    [Arguments]    ${endpoint}    ${name}    ${verify}
    ${response}=    GET    url=${endpoint}/system/services/${name}
    ...    headers=${HEADERS}    expected_status=ANY    verify=${verify}
    Should Be Equal As Integers    ${response.status_code}    200

Deployment Should Be Ready
    [Arguments]    ${endpoint}    ${name}    ${verify}
    ${response}=    GET    url=${endpoint}/system/services/${name}/deployment
    ...    headers=${HEADERS}    expected_status=200    verify=${verify}
    ${state}=    Evaluate    json.loads($response.content).get('state')    modules=json
    Should Be Equal As Strings    ${state}    ready    Service deployment is not ready (state: ${state})

Get Jobs
    [Arguments]    ${endpoint}    ${name}    ${verify}
    ${response}=    GET    url=${endpoint}/system/logs/${name}
    ...    headers=${HEADERS}    expected_status=200    verify=${verify}
    ${payload}=    Evaluate    json.loads($response.content)    modules=json
    Should Be Empty    ${payload.get('next_page', '')}    Cannot establish absence with a paginated job list
    ${jobs}=    Evaluate    $payload.get('jobs') or {}
    RETURN    ${jobs}

Delegated Job Should Succeed
    ${local}=    Get Jobs    ${ORIGIN_ENDPOINT}    ${ORIGIN_NAME}    ${ORIGIN_VERIFY}
    Should Be Empty    ${local}    Job ran on the origin rather than being delegated
    ${remote}=    Get Jobs    ${TARGET_ENDPOINT}    ${WORKER_NAME}    ${TARGET_VERIFY}
    # OSCAR truncates service names >=25 characters to 16 before appending the job UUID.
    ${prefix}=    Evaluate    $ORIGIN_NAME[:16] if len($ORIGIN_NAME) >= 25 else $ORIGIN_NAME
    ${matching}=    Evaluate    {k: v for k, v in $remote.items() if k.startswith($prefix + '-')}
    IF    len($remote) != len($matching)
        Fail    Unexpected destination Jobs for this test-owned worker
    END
    Length Should Be    ${matching}    1
    ${name}=    Evaluate    next(iter($matching))
    Set Suite Variable    ${JOB_ID}    ${name}
    ${status}=    Evaluate    $matching[$name]['status']
    Should Be Equal As Strings    ${status}    Succeeded

Cleanup Delegation Fixture
    IF    not ${FIXTURE_ATTEMPTED}
        RETURN
    END
    ${keep}=    Convert To Boolean    ${KEEP_SERVICES}
    IF    ${keep}
        Log To Console    Preserved test fixtures: origin=${ORIGIN_NAME}, worker=${WORKER_NAME}, job=${JOB_ID}
        RETURN
    END
    # Both services were absent before this test attempted creation; cancel only their Jobs.
    # Continue trying to remove each service even when one cleanup step fails.
    Run Keyword And Continue On Failure    Delete Fixture Jobs    ${ORIGIN_ENDPOINT}    ${ORIGIN_NAME}    ${ORIGIN_VERIFY}
    Run Keyword And Continue On Failure    Delete Fixture Jobs    ${TARGET_ENDPOINT}    ${WORKER_NAME}    ${TARGET_VERIFY}
    Run Keyword And Continue On Failure    Delete Own Service    ${ORIGIN_ENDPOINT}    ${ORIGIN_NAME}    ${ORIGIN_VERIFY}
    Run Keyword And Continue On Failure    Delete Own Service    ${TARGET_ENDPOINT}    ${WORKER_NAME}    ${TARGET_VERIFY}

Delete Fixture Jobs
    [Arguments]    ${endpoint}    ${name}    ${verify}
    ${existing}=    GET    url=${endpoint}/system/services/${name}
    ...    headers=${HEADERS}    expected_status=ANY    verify=${verify}
    IF    $existing.status_code == 404
        RETURN
    END
    Should Be Equal As Integers    ${existing.status_code}    200
    ${jobs}=    Get Jobs    ${endpoint}    ${name}    ${verify}
    ${job_names}=    Evaluate    list($jobs)
    FOR    ${job}    IN    @{job_names}
        ${response}=    DELETE    url=${endpoint}/system/logs/${name}/${job}
        ...    headers=${HEADERS}    expected_status=ANY    verify=${verify}
        Should Be True    $response.status_code in (204, 404)    Could not cancel a test-owned Job
    END
    Wait Until Keyword Succeeds    30s    2s    Fixture Jobs Must Be Empty    ${endpoint}    ${name}    ${verify}

Fixture Jobs Must Be Empty
    [Arguments]    ${endpoint}    ${name}    ${verify}
    ${remaining}=    Get Jobs    ${endpoint}    ${name}    ${verify}
    Should Be Empty    ${remaining}    Test-owned Jobs remain after cancellation

Delete Own Service
    [Arguments]    ${endpoint}    ${name}    ${verify}
    ${existing}=    GET    url=${endpoint}/system/services/${name}
    ...    headers=${HEADERS}    expected_status=ANY    verify=${verify}
    IF    $existing.status_code == 404
        RETURN
    END
    Should Be Equal As Integers    ${existing.status_code}    200
    ${response}=    DELETE    url=${endpoint}/system/services/${name}
    ...    headers=${HEADERS}    expected_status=ANY    verify=${verify}
    Should Be Equal As Integers    ${response.status_code}    204
    Service Must Not Exist    ${endpoint}    ${name}    ${verify}
