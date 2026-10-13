*** Settings ***
Documentation       Tests for the OSCAR Manager's API of a deployed OSCAR cluster. Deploys and exercises the
...                 orchestration chain defined in data/orchestration/orquestation.yaml (grayify -> grayify-next).

Library             Collections
Library             OperatingSystem
Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/api_call.resource
Resource            ${CURDIR}/../../resources/service.resource


Suite Setup         Run Keywords    Check Valid OIDC Token    AND    Initialize Orchestration Names    AND    Create Orchestration Test Image
Suite Teardown      Run Keywords    Cleanup Orchestration Resources    AND    Remove Orchestration Artifacts


*** Variables ***
${SERVICE_BASE}            robot-orchestration
${ORCHESTRATION_DIR}       ${DATA_DIR}/orchestration
${ORCHESTRATION_YAML}      ${ORCHESTRATION_DIR}/orquestation.yaml
${ORCHESTRATION_SCRIPT}    ${ORCHESTRATION_DIR}/script.sh
${TEST_IMAGE_NAME}         test-image.png
${TEST_IMAGE}              ${ORCHESTRATION_DIR}/${TEST_IMAGE_NAME}
${OUTPUT_IMAGE}            ${ORCHESTRATION_DIR}/orchestration-output.png
${SERVICE1_FILE}           ${ORCHESTRATION_DIR}/service1.json
${SERVICE2_FILE}           ${ORCHESTRATION_DIR}/service2.json
${FIRST_SERVICE}           ${EMPTY}
${SECOND_SERVICE}          ${EMPTY}
${FIRST_INPUT}             ${EMPTY}
${FIRST_OUTPUT}            ${EMPTY}
${SECOND_INPUT}            ${EMPTY}
${SECOND_OUTPUT}           ${EMPTY}


*** Test Cases ***
OSCAR API Health
    [Documentation]    Check API health
    ${response}=    GET With Defaults    ${OSCAR_ENDPOINT}/health
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

OSCAR Create Orchestration Services
    [Documentation]    Deploy the grayify and grayify-next services keeping the chained input/output paths
    [Tags]    create    ready
    Prepare Orchestration Service Files
    ${body1}=    Get File    ${SERVICE1_FILE}
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body1}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'    #409 if already exists
    ${body2}=    Get File    ${SERVICE2_FILE}
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body2}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'    #409 if already exists
    Wait For Service Ready    ${FIRST_SERVICE}
    Wait For Service Ready    ${SECOND_SERVICE}

OSCAR List Orchestration Services
    [Documentation]    Retrieve a list of services including the orchestration chain
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services
    Log    ${response.content}
    Should Contain    ${response.content}    "oscar_service":
    Should Contain    ${response.content}    ${FIRST_SERVICE}
    Should Contain    ${response.content}    ${SECOND_SERVICE}

OSCAR List Orchestration Buckets
    [Documentation]    Retrieve the buckets created for the orchestration services and check they are tagged with the originating service
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/buckets
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    ${buckets}=    Evaluate    json.loads($response.content)    json
    Verify Bucket Is Tagged From Service    ${buckets}    ${FIRST_SERVICE}
    Verify Bucket Is Tagged From Service    ${buckets}    ${SECOND_SERVICE}

OSCAR Read Orchestration Services
    [Documentation]    Read both services and verify the chained input/output paths
    ${service}=    Get Service Payload    ${FIRST_SERVICE}
    Should Be Equal As Strings    ${service}[name]    ${FIRST_SERVICE}
    Verify Orchestration Chain    ${service}    ${FIRST_INPUT}    ${FIRST_OUTPUT}
    ${service}=    Get Service Payload    ${SECOND_SERVICE}
    Should Be Equal As Strings    ${service}[name]    ${SECOND_SERVICE}
    Verify Orchestration Chain    ${service}    ${SECOND_INPUT}    ${SECOND_OUTPUT}

OSCAR Update Orchestration Services
    [Documentation]    Update the orchestration services
    ${body1}=    Get File    ${SERVICE1_FILE}
    ${response}=    PUT With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body1}    expected_status=ANY
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'
    ${body2}=    Get File    ${SERVICE2_FILE}
    ${response}=    PUT With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body2}    expected_status=ANY
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'
    Wait For Service Ready    ${FIRST_SERVICE}
    Wait For Service Ready    ${SECOND_SERVICE}

OSCAR Invoke Orchestration Pipeline
    [Documentation]    Upload a test image to the first service input and verify the chained output is produced
    [Tags]    ready
    Upload Test Image To First Service Input
    Wait Until Keyword Succeeds    300s    10s    Orchestration Output Object Should Exist
    Download And Verify Orchestration Output

OSCAR Delete Orchestration Services
    [Documentation]    Delete the orchestration services and verify that buckets and their tags are cleaned up
    [Tags]    delete
    Skip If    '${LOCAL_TESTING}'=='True'    #Skipping in local testing for the time being
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${FIRST_SERVICE}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204
    Wait Until Keyword Succeeds    60s    5s    Bucket Should Not Exist    ${FIRST_SERVICE}
    Wait Until Keyword Succeeds    60s    5s    Bucket Should Not Be Tagged With Service    ${SECOND_SERVICE}    ${FIRST_SERVICE}
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/buckets
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    ${buckets}=    Evaluate    json.loads($response.content)    json
    Verify Bucket Is Tagged From Service    ${buckets}    ${SECOND_SERVICE}
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SECOND_SERVICE}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204
    Wait Until Keyword Succeeds    60s    5s    Bucket Should Not Exist    ${SECOND_SERVICE}


*** Keywords ***
Initialize Orchestration Names
    [Documentation]    Generate unique names for the two chained services and their storage paths
    ${suffix}=    Evaluate    ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))    modules=random,string
    Set Suite Variable    ${FIRST_SERVICE}    ${SERVICE_BASE}-${suffix}
    Set Suite Variable    ${SECOND_SERVICE}    ${SERVICE_BASE}-${suffix}-next
    Set Suite Variable    ${FIRST_INPUT}     ${FIRST_SERVICE}/in
    Set Suite Variable    ${FIRST_OUTPUT}    ${SECOND_SERVICE}/in
    Set Suite Variable    ${SECOND_INPUT}    ${SECOND_SERVICE}/in
    Set Suite Variable    ${SECOND_OUTPUT}   ${SECOND_SERVICE}/out

Create Orchestration Test Image
    [Documentation]    Generate a small colored PNG used as input for the grayify chain
    ${b64}=    Set Variable    iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAoElEQVR4nA3K0QAEMQxF0SAMQhAGIQhFeAhFCEIRgjAIQViEmNzt+T5mZrg9hDmyl7SgbNEmxjZm/uDuhL/Ig/RFuWjfjOcN4Xi8RASKRYao2HQkE+cGvbiC0EISqU0paR1GdUMGnotIodxkJpWHzmLyu6EWXiJqo0qyDlVF18dU39DCexOdqA/ZRfVHdzP9u2E2PknMQVPkfNQ0PT9mhj/jRpPBCB3RYQAAAABJRU5ErkJggg==
    ${png_bytes}=    Evaluate    base64.b64decode($b64)    modules=base64
    Create Binary File    ${TEST_IMAGE}    ${png_bytes}
    File Should Exist    ${TEST_IMAGE}

Prepare Orchestration Service Files
    [Documentation]    Load data/orchestration/orquestation.yaml and generate a JSON file per service
    ${yaml_content}=    Get File    ${ORCHESTRATION_YAML}
    ${service_content}=    yaml.Safe Load    ${yaml_content}
    ${oscar_list}=    Get From Dictionary    ${service_content}[functions]    oscar
    Prepare Single Orchestration Service    ${oscar_list}    0    ${FIRST_SERVICE}    ${FIRST_INPUT}    ${FIRST_OUTPUT}    ${SERVICE1_FILE}
    Prepare Single Orchestration Service    ${oscar_list}    1    ${SECOND_SERVICE}    ${SECOND_INPUT}    ${SECOND_OUTPUT}    ${SERVICE2_FILE}

Prepare Single Orchestration Service
    [Documentation]    Extract one service from the list, set name, script, VO and the chained storage paths
    [Arguments]    ${oscar_list}    ${index}    ${service_name}    ${input_path}    ${output_path}    ${saved_file}
    ${item}=    Get From List    ${oscar_list}    ${index}
    ${keys}=    Get Dictionary Keys    ${item}
    ${cluster_key}=    Get From List    ${keys}    0
    ${cluster}=    Get From Dictionary    ${item}    ${cluster_key}
    Set To Dictionary    ${cluster}    name=${service_name}
    Set To Dictionary    ${cluster}    vo=${VO}
    ${script_content}=    Get File    ${ORCHESTRATION_SCRIPT}
    Set To Dictionary    ${cluster}    script=${script_content}
    ${inputs}=    Get From Dictionary    ${cluster}    input
    ${first_input}=    Get From List    ${inputs}    0
    Set To Dictionary    ${first_input}    path=${input_path}
    ${outputs}=    Get From Dictionary    ${cluster}    output
    ${first_output}=    Get From List    ${outputs}    0
    Set To Dictionary    ${first_output}    path=${output_path}
    ${json_string}=    Evaluate    json.dumps(${cluster})    json
    Create File    ${saved_file}    ${json_string}

Get Service Payload
    [Documentation]    Fetch a service and return its parsed JSON payload
    [Arguments]    ${service_name}
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    RETURN    ${payload}

Verify Orchestration Chain
    [Documentation]    Assert that the first input/output entries of a service use the expected paths
    [Arguments]    ${service}    ${expected_input}    ${expected_output}
    ${inputs}=    Get From Dictionary    ${service}    input
    ${outputs}=    Get From Dictionary    ${service}    output
    ${first_input}=    Get From List    ${inputs}    0
    ${first_output}=    Get From List    ${outputs}    0
    Should Be Equal As Strings    ${first_input}[path]    ${expected_input}
    Should Be Equal As Strings    ${first_output}[path]    ${expected_output}

Verify Bucket Is Tagged From Service
    [Documentation]    Assert that a bucket exists and its metadata is tagged with the originating service
    [Arguments]    ${buckets}    ${service_name}
    ${bucket}=    Get Bucket From List    ${buckets}    ${service_name}
    ${metadata}=    Get From Dictionary    ${bucket}    metadata
    Dictionary Should Contain Key    ${metadata}    from_service
    ${from_service}=    Get From Dictionary    ${metadata}    from_service
    ${tags}=    Evaluate    $from_service.split()
    List Should Contain Value    ${tags}    ${service_name}    Bucket ${service_name} is not tagged with the originating service

Get Bucket From List
    [Documentation]    Return the bucket dictionary matching a name or fail if it is not present
    [Arguments]    ${buckets}    ${bucket_name}
    FOR    ${bucket}    IN    @{buckets}
        ${name}=    Get From Dictionary    ${bucket}    bucket_name
        IF    '${name}' == '${bucket_name}'
            RETURN    ${bucket}
        END
    END
    Fail    Bucket ${bucket_name} not found in the bucket list

List Buckets Payload
    [Documentation]    Fetch and parse the list of buckets
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/buckets
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    RETURN    ${payload}

Bucket Should Not Exist
    [Documentation]    Assert that the given bucket is no longer present in the bucket list
    [Arguments]    ${bucket_name}
    ${buckets}=    List Buckets Payload
    ${found}=    Evaluate    any(b.get('bucket_name') == r'''${bucket_name}''' for b in $buckets)
    Should Be True    not ${found}    Bucket ${bucket_name} still exists

Bucket Should Not Be Tagged With Service
    [Documentation]    Assert that an existing bucket is tagged with the remaining service but no longer with the removed one
    [Arguments]    ${bucket_name}    ${removed_service}
    ${buckets}=    List Buckets Payload
    ${bucket}=    Get Bucket From List    ${buckets}    ${bucket_name}
    ${metadata}=    Get From Dictionary    ${bucket}    metadata
    Dictionary Should Contain Key    ${metadata}    from_service
    ${from_service}=    Get From Dictionary    ${metadata}    from_service
    ${tags}=    Evaluate    $from_service.split()
    List Should Contain Value    ${tags}    ${bucket_name}    Bucket ${bucket_name} is not tagged with the originating service any more
    List Should Not Contain Value    ${tags}    ${removed_service}    Bucket ${bucket_name} is still tagged with the removed service ${removed_service}

Wait For Service Ready
    [Documentation]    Polls the service endpoint until the service reports a ready state or the timeout expires
    [Arguments]    ${service_name}
    Wait Until Keyword Succeeds    210s    5s    Service Should Be Ready    ${service_name}

Service Should Be Ready
    [Documentation]    Asserts that the service status indicates readiness
    [Arguments]    ${service_name}
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=200
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${status}=    Evaluate
    ...    (lambda d: d.get('status') if not isinstance(d.get('status'), dict) else d['status'].get('state') or d['status'].get('phase') or d['status'].get('condition'))(${payload})
    ...    json
    ${ready}=    Evaluate
    ...    str(${status}).lower() in ("ready","running","available","succeeded") or bool(${payload}.get('ready')) or bool(${payload}.get('token'))
    ...    json
    Should Be True    ${ready}    Service not ready yet (status=${status})

Create Presign Payload
    [Documentation]    Build a JSON payload for the buckets presign endpoint
    [Arguments]    ${object_key}    ${operation}=download    ${expires}=0
    ${payload}=    Create Dictionary    object_key=${object_key}    operation=${operation}
    IF    ${expires} > 0
        Set To Dictionary    ${payload}    expires=${expires}
    END
    ${body}=    Evaluate    json.dumps(${payload})    json
    RETURN    ${body}

Upload Test Image To First Service Input
    [Documentation]    Presign an upload URL for the first service input path and PUT the test image
    ${body}=    Create Presign Payload    in/${TEST_IMAGE_NAME}    upload
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/${FIRST_SERVICE}/presign    data=${body}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${upload_url}=    Get From Dictionary    ${payload}    url
    Log    Upload URL: ${upload_url}
    ${image_bytes}=    Get Binary File    ${TEST_IMAGE}
    ${upload_response}=    PUT    url=${upload_url}    data=${image_bytes}    expected_status=ANY    verify=${SSL_VERIFY}
    Log    Upload status: ${upload_response.status_code}
    Should Be Equal As Strings    ${upload_response.status_code}    200

Orchestration Output Object Should Exist
    [Documentation]    Presign a download URL for the second service output and check the object is present
    ${body}=    Create Presign Payload    out/${TEST_IMAGE_NAME}    download
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/${SECOND_SERVICE}/presign    data=${body}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${download_url}=    Get From Dictionary    ${payload}    url
    Set Suite Variable    ${DOWNLOAD_URL}    ${download_url}
    ${out_response}=    GET    url=${download_url}    expected_status=ANY    verify=${SSL_VERIFY}
    Log    Output status: ${out_response.status_code}
    Should Be Equal As Strings    ${out_response.status_code}    200
    Should Not Be Empty    ${out_response.content}

Download And Verify Orchestration Output
    [Documentation]    Download the produced image, check it is a valid PNG and different from the input
    ${response}=    GET    url=${DOWNLOAD_URL}    expected_status=200    verify=${SSL_VERIFY}
    Log    ${response.content}
    Create Binary File    ${OUTPUT_IMAGE}    ${response.content}
    File Should Exist    ${OUTPUT_IMAGE}
    ${input_hash}=    Evaluate    hashlib.md5(open(r'''${TEST_IMAGE}''', 'rb').read()).hexdigest()    modules=hashlib
    ${output_hash}=    Evaluate    hashlib.md5(open(r'''${OUTPUT_IMAGE}''', 'rb').read()).hexdigest()    modules=hashlib
    Log    Input hash: ${input_hash} - Output hash: ${output_hash}
    Should Not Be Equal As Strings    ${input_hash}    ${output_hash}    Output is identical to the input; the grayify pipeline did not run
    ${png_ok}=    Evaluate    open(r'''${OUTPUT_IMAGE}''', 'rb').read(8) == base64.b64decode('iVBORw0KGgo=')    modules=base64
    Should Be True    ${png_ok}    Output is not a valid PNG file

Cleanup Orchestration Resources
    [Documentation]    Best-effort cleanup of services, logs and buckets created by this suite
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${FIRST_SERVICE}?all=true    expected_status=ANY
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${SECOND_SERVICE}?all=true    expected_status=ANY
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${FIRST_SERVICE}    expected_status=ANY
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SECOND_SERVICE}    expected_status=ANY
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/${FIRST_SERVICE}    expected_status=ANY
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/${SECOND_SERVICE}    expected_status=ANY

Remove Orchestration Artifacts
    [Documentation]    Remove the temporary files generated by this suite
    Run Keyword And Ignore Error    Remove File    ${SERVICE1_FILE}
    Run Keyword And Ignore Error    Remove File    ${SERVICE2_FILE}
    Run Keyword And Ignore Error    Remove File    ${TEST_IMAGE}
    Run Keyword And Ignore Error    Remove File    ${OUTPUT_IMAGE}