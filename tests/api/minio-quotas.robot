*** Settings ***
Documentation       Validate MinIO bucket quotas through the OSCAR API.

Library             Collections
Library             OperatingSystem
Library             Process
Library             RequestsLibrary
Library             String

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/api_call.resource
Resource            ${CURDIR}/../../resources/files.resource

Suite Setup         Run Keywords    Check Valid OIDC Token    AND    Initialize MinIO Quota Test
Suite Teardown      Run Keywords    Cleanup MinIO Storage Enforcement Resources    AND    Cleanup MinIO Quota Buckets    AND    Restore Original MinIO Quota


*** Variables ***
${MINIO_STORAGE_PER_BUCKET}     50Mi
${BUCKET_A}                     ${EMPTY}
${BUCKET_B}                     ${EMPTY}
${CLI_CLUSTER}                  ${EMPTY}
${ORIGINAL_MINIO_BUCKETS_MAX}   ${EMPTY}
${ORIGINAL_MINIO_STORAGE_MAX}   ${EMPTY}
${QUOTA_SERVICE_NAME}           ${EMPTY}
${QUOTA_SERVICE_BUCKET}         ${EMPTY}
${SMALL_OBJECT_FILE}            ${DATA_DIR}/minio-quota-small.bin
${LARGE_OBJECT_FILE}            ${DATA_DIR}/minio-quota-large.bin
${RETRY_OBJECT_FILE}            ${DATA_DIR}/minio-quota-retry.bin


*** Test Cases ***
OSCAR MinIO Quotas Are Reported
    [Documentation]    /system/quotas/user exposes MinIO bucket count and storage quota information.
    ${payload}=    Fetch User Quotas Payload
    Dictionary Should Contain Key    ${payload}    minio
    ${minio}=    Get From Dictionary    ${payload}    minio
    Dictionary Should Contain Key    ${minio}    buckets
    Dictionary Should Contain Key    ${minio}    storage_per_bucket
    Dictionary Should Contain Key    ${minio}    storage_total
    Dictionary Should Contain Key    ${minio["buckets"]}    max
    Dictionary Should Contain Key    ${minio["buckets"]}    used
    Dictionary Should Contain Key    ${minio["storage_per_bucket"]}    max
    Dictionary Should Contain Key    ${minio["storage_total"]}    used

OSCAR Enforces MinIO Bucket Count Quota
    [Documentation]    Creating one more bucket than the configured MinIO bucket quota is rejected.
    ${payload}=    Fetch User Quotas Payload
    ${used}=    Evaluate    int($payload["minio"]["buckets"]["used"])
    ${limit}=    Evaluate    ${used} + 1
    Update MinIO Quota    ${limit}    ${MINIO_STORAGE_PER_BUCKET}
    ${response}=    Create MinIO Bucket    ${BUCKET_A}
    Should Be Equal As Strings    ${response.status_code}    201
    ${response}=    Create MinIO Bucket    ${BUCKET_B}
    Should Be Equal As Strings    ${response.status_code}    403
    Should Contain Any    ${response.content}    quota    limit    bucket
    ${updated}=    Fetch User Quotas Payload
    Should Be Equal As Integers    ${updated["minio"]["buckets"]["max"]}    ${limit}
    Should Be True    ${updated["minio"]["buckets"]["used"]} >= ${limit}

OSCAR Applies MinIO Storage Quota To New Buckets
    [Documentation]    A bucket created through /system/buckets receives the configured per-bucket storage quota.
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/${BUCKET_A}    expected_status=200
    Log    ${response.content}
    ${bucket}=    Evaluate    json.loads($response.content)    json
    Dictionary Should Contain Key    ${bucket}    storage_quota
    Should Be Equal As Strings    ${bucket["storage_quota"]["max"]}    ${MINIO_STORAGE_PER_BUCKET}

OSCAR Enforces MinIO Storage Per Bucket Quota
    [Documentation]    MinIO rejects further object uploads after its scanner observes that a bucket exceeded the configured quota.
    [Tags]    storage-enforcement    oscar-cli
    Ensure OSCAR CLI Cluster Configured
    ${payload}=    Fetch User Quotas Payload
    ${limit}=    Evaluate    int($payload["minio"]["buckets"]["used"]) + 1
    Update MinIO Quota    ${limit}    1Mi
    Create Quota Test Files
    Create MinIO Quota Service
    Wait Until Keyword Succeeds    180s    5s    Service Should Exist    ${QUOTA_SERVICE_NAME}
    Wait Until Keyword Succeeds    60s    5s    Service Bucket Should Have Storage Quota    1Mi
    ${small_result}=    Run Process    oscar-cli    service    put-file    ${QUOTA_SERVICE_NAME}    minio.default
    ...    ${SMALL_OBJECT_FILE}    ${QUOTA_SERVICE_BUCKET}/input/small.bin    stdout=True    stderr=True
    Log    ${small_result.stdout}
    Log    ${small_result.stderr}
    Should Be Equal As Integers    ${small_result.rc}    0
    ${large_result}=    Run Process    oscar-cli    service    put-file    ${QUOTA_SERVICE_NAME}    minio.default
    ...    ${LARGE_OBJECT_FILE}    ${QUOTA_SERVICE_BUCKET}/input/large.bin    stdout=True    stderr=True
    Log    ${large_result.stdout}
    Log    ${large_result.stderr}
    Should Be Equal As Integers    ${large_result.rc}    0
    Wait Until Keyword Succeeds    180s    10s    Service Bucket Usage Should Exceed Quota
    Wait Until Keyword Succeeds    240s    15s    MinIO Should Reject Additional Upload


*** Keywords ***
Initialize MinIO Quota Test
    [Documentation]    Prepare unique bucket names and capture the current MinIO quota for restoration.
    ${suffix}=    Generate Random String    8    [LOWER][NUMBERS]
    Set Suite Variable    ${BUCKET_A}    robot-minio-quota-${suffix}-a
    Set Suite Variable    ${BUCKET_B}    robot-minio-quota-${suffix}-b
    Set Suite Variable    ${CLI_CLUSTER}    robot-minio-quota-${suffix}
    Set Suite Variable    ${QUOTA_SERVICE_NAME}    robot-minio-quota-svc-${suffix}
    Set Suite Variable    ${QUOTA_SERVICE_BUCKET}    robot-minio-quota-svc-${suffix}
    Cleanup MinIO Quota Buckets
    ${payload}=    Fetch User Quotas Payload
    ${has_minio}=    Evaluate    "minio" in $payload
    Skip If    not ${has_minio}    This OSCAR deployment does not expose MinIO quota information.
    Set Suite Variable    ${ORIGINAL_MINIO_BUCKETS_MAX}    ${payload["minio"]["buckets"]["max"]}
    Set Suite Variable    ${ORIGINAL_MINIO_STORAGE_MAX}    ${payload["minio"]["storage_per_bucket"]["max"]}

Fetch User Quotas Payload
    [Documentation]    Read the current user's quota payload.
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/quotas/user    expected_status=ANY
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    RETURN    ${payload}

Update MinIO Quota
    [Documentation]    Update MinIO bucket-count and per-bucket storage quotas for the current user.
    [Arguments]    ${bucket_limit}    ${storage_per_bucket}
    ${body}=    Evaluate    json.dumps({"minio": {"buckets": str($bucket_limit), "storage_per_bucket": $storage_per_bucket}})    json
    ${response}=    PUT With Defaults    url=${OSCAR_ENDPOINT}/system/quotas/user/${USER}    data=${body}    expected_status=200    headers=${HEADERS_OSCAR}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200

Create MinIO Bucket
    [Documentation]    Create a private MinIO bucket through the OSCAR buckets API.
    [Arguments]    ${bucket_name}
    ${body}=    Evaluate    json.dumps({"bucket_name": $bucket_name, "visibility": "private", "allowed_users": []})    json
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/buckets    data=${body}
    Log    ${response.content}
    RETURN    ${response}

Ensure OSCAR CLI Cluster Configured
    [Documentation]    Configure oscar-cli for the target OSCAR endpoint.
    ${cli_check}=    Run Process    oscar-cli    stdout=True    stderr=True
    Log    ${cli_check.stdout}
    Log    ${cli_check.stderr}
    Should Be Equal As Integers    ${cli_check.rc}    0
    ${has_basic}=    Run Keyword And Return Status    Variable Should Exist    ${BASIC_USER}
    IF    ${has_basic} and '${BASIC_USER}' != ''
        Set CLI Basic Credentials
        ${add_result}=    Run Process    oscar-cli    cluster    add    ${CLI_CLUSTER}    ${OSCAR_ENDPOINT}
        ...    ${OSCAR_USER}    ${OSCAR_PASSWORD}    stdout=True    stderr=True
    ELSE
        ${has_refresh}=    Run Keyword And Return Status    Variable Should Exist    ${REFRESH_TOKEN}
        IF    not ${has_refresh}
            Set Refresh Token
        END
        ${add_result}=    Run Process    oscar-cli    cluster    add    ${CLI_CLUSTER}    ${OSCAR_ENDPOINT}
        ...    --oidc-refresh-token    ${REFRESH_TOKEN}    stdout=True    stderr=True
    END
    Log    ${add_result.stdout}
    Log    ${add_result.stderr}
    Should Be Equal As Integers    ${add_result.rc}    0
    ${default_result}=    Run Process    oscar-cli    cluster    default    --set    ${CLI_CLUSTER}    stdout=True    stderr=True
    Log    ${default_result.stdout}
    Log    ${default_result.stderr}
    Should Be Equal As Integers    ${default_result.rc}    0

Set CLI Basic Credentials
    [Documentation]    Decode BASIC_USER and store username/password for oscar-cli.
    ${decoded}=    Evaluate    base64.b64decode('${BASIC_USER}').decode('utf-8')    modules=base64
    @{credentials}=    Split String    ${decoded}    :
    Set Suite Variable    ${OSCAR_USER}    ${credentials}[0]
    Set Suite Variable    ${OSCAR_PASSWORD}    ${credentials}[1]

Create Quota Test Files
    [Documentation]    Create files below and above the configured 1Mi bucket quota.
    Evaluate    open(r'''${SMALL_OBJECT_FILE}''', 'wb').write(b'0' * 524288)
    Evaluate    open(r'''${LARGE_OBJECT_FILE}''', 'wb').write(b'0' * 786432)
    Evaluate    open(r'''${RETRY_OBJECT_FILE}''', 'wb').write(b'0' * 262144)
    File Should Exist    ${SMALL_OBJECT_FILE}
    File Should Exist    ${LARGE_OBJECT_FILE}
    File Should Exist    ${RETRY_OBJECT_FILE}

Create MinIO Quota Service
    [Documentation]    Create a temporary service with one MinIO bucket used for input and output.
    ${input}=    Create Dictionary    storage_provider=minio    path=${QUOTA_SERVICE_BUCKET}/input
    ${output}=    Create Dictionary    storage_provider=minio    path=${QUOTA_SERVICE_BUCKET}/output
    @{inputs}=    Create List    ${input}
    @{outputs}=    Create List    ${output}
    ${body}=    Evaluate
    ...    json.dumps({"name": $QUOTA_SERVICE_NAME, "cpu": "0.1", "memory": "128Mi", "image": "ghcr.io/grycap/cowsay", "script": "#!/bin/sh\\ncat $INPUT_FILE_PATH\\n", "input": $inputs, "output": $outputs, "vo": $VO, "isolation_level": "SERVICE", "visibility": "private"})
    ...    json
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'

Service Should Exist
    [Documentation]    Assert that a service can be read from the OSCAR API.
    [Arguments]    ${service_name}
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=200
    Should Be Equal As Strings    ${response.status_code}    200

Service Bucket Should Have Storage Quota
    [Documentation]    Assert that the service bucket has the expected MinIO storage quota before uploading objects.
    [Arguments]    ${expected_quota}
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/${QUOTA_SERVICE_BUCKET}    expected_status=200
    Log    ${response.content}
    ${bucket}=    Evaluate    json.loads($response.content)    json
    Dictionary Should Contain Key    ${bucket}    storage_quota
    Should Be Equal As Strings    ${bucket["storage_quota"]["max"]}    ${expected_quota}

Service Bucket Usage Should Exceed Quota
    [Documentation]    Assert that OSCAR reports bucket usage above the configured 1Mi quota.
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/${QUOTA_SERVICE_BUCKET}    expected_status=200
    Log    ${response.content}
    ${bucket}=    Evaluate    json.loads($response.content)    json
    Dictionary Should Contain Key    ${bucket}    storage_usage
    ${used_bytes}=    Evaluate    int($bucket["storage_usage"]["used_bytes"])
    Should Be True    ${used_bytes} > 1048576    Bucket usage is not above quota yet: ${used_bytes} bytes

MinIO Should Reject Additional Upload
    [Documentation]    Try another upload after quota overuse is visible; MinIO scanner enforcement is best-effort and delayed.
    ${suffix}=    Generate Random String    6    [LOWER][NUMBERS]
    ${result}=    Run Process    oscar-cli    service    put-file    ${QUOTA_SERVICE_NAME}    minio.default
    ...    ${RETRY_OBJECT_FILE}    ${QUOTA_SERVICE_BUCKET}/input/retry-${suffix}.bin    stdout=True    stderr=True
    Log    ${result.stdout}
    Log    ${result.stderr}
    Should Not Be Equal As Integers    ${result.rc}    0    msg=Quota is configured and exceeded, but MinIO still accepted an additional upload within the timeout.
    ${combined_output}=    Catenate    SEPARATOR=\n    ${result.stdout}    ${result.stderr}
    Should Contain Any    ${combined_output}    quota    exceed    limit    storage

Cleanup MinIO Quota Buckets
    [Documentation]    Remove buckets created by this suite if they exist.
    Run Keyword If    '${BUCKET_A}' != ''    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/${BUCKET_A}    expected_status=ANY
    Run Keyword If    '${BUCKET_B}' != ''    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/${BUCKET_B}    expected_status=ANY

Cleanup MinIO Storage Enforcement Resources
    [Documentation]    Remove service, bucket, CLI cluster, and temporary files used by storage enforcement.
    Run Keyword If    '${QUOTA_SERVICE_NAME}' != ''    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${QUOTA_SERVICE_NAME}    expected_status=ANY
    Run Keyword If    '${QUOTA_SERVICE_BUCKET}' != ''    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/${QUOTA_SERVICE_BUCKET}    expected_status=ANY
    Run Keyword If    '${CLI_CLUSTER}' != ''    Run Process    oscar-cli    cluster    remove    ${CLI_CLUSTER}    stdout=True    stderr=True
    Remove File    ${SMALL_OBJECT_FILE}
    Remove File    ${LARGE_OBJECT_FILE}
    Remove File    ${RETRY_OBJECT_FILE}

Restore Original MinIO Quota
    [Documentation]    Restore the MinIO quota values captured at suite startup.
    Run Keyword If    '${ORIGINAL_MINIO_BUCKETS_MAX}' != '' and '${ORIGINAL_MINIO_STORAGE_MAX}' != ''
    ...    Update MinIO Quota    ${ORIGINAL_MINIO_BUCKETS_MAX}    ${ORIGINAL_MINIO_STORAGE_MAX}

Should Contain Any
    [Documentation]    Assert that the text contains at least one of the provided fragments.
    [Arguments]    ${text}    @{fragments}
    ${text_str}=    Convert To String    ${text}
    ${text_lower}=    Convert To Lower Case    ${text_str}
    ${found}=    Set Variable    ${False}
    FOR    ${fragment}    IN    @{fragments}
        ${fragment_lower}=    Convert To Lower Case    ${fragment}
        ${contains}=    Evaluate    $fragment_lower in $text_lower
        IF    ${contains}
            ${found}=    Set Variable    ${True}
        END
    END
    Should Be True    ${found}    Expected response to contain one of ${fragments}, got: ${text}
