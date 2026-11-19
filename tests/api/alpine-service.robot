*** Settings ***
Documentation    Verifies that a service based on the minimal alpine image can be created, becomes ready,
...    and its script runs correctly when the service is invoked synchronously.

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/api_call.resource
Resource            ${CURDIR}/../../resources/service.resource



Suite Setup         Run Keywords    Check Valid OIDC Token    AND    Assign Random Service Name



Suite Teardown      Run Keywords    Cleanup Alpine Service Resources    AND    Clean Test Artifacts    ${ALPINE_SERVICE_FILE}


*** Variables ***
${SERVICE_BASE}     robot-test-alpine
${SERVICE_NAME}     ${SERVICE_BASE}
${ALPINE_IMAGE}     alpine
${EXPECTED_OUTPUT}  ALPINE_TEST_OK
${ALPINE_SERVICE_FILE}    ${ARTIFACTS_DIR}/alpine_service_file.json


*** Test Cases ***
OSCAR Create Service from Alpine Image
    [Documentation]    Create a service based on the alpine image and wait until it is ready
    [Tags]    create    ready
    Prepare Alpine Service File
    ${body}=    Get File    ${ALPINE_SERVICE_FILE}
    ${response}=    POST With Defaults  url=${OSCAR_ENDPOINT}/system/services   data=${body}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '201'    Service creation failed: ${response.content}
    Wait For Alpine Service Ready

OSCAR Invoke Synchronous Service from Alpine Image
    [Documentation]    Invoke the alpine-based service synchronously and verify the script output
    [Tags]    ready
    VAR    ${body}=        ${EXPECTED_OUTPUT}
    FOR    ${i}    IN RANGE    ${MAX_RETRIES}
        ${status}    ${resp}=    Run Keyword And Ignore Error    POST    url=${OSCAR_ENDPOINT}/run/${SERVICE_NAME}      expected_status=ANY    verify=${SSL_VERIFY}    headers=${HEADERS}       data=${body}
        IF    '${status}' != 'FAIL'
            Log     ${status}
            Log     ${resp.content}
            ${contains_output}=    Run Keyword And Return Status    Should Contain    ${resp.text}    ${EXPECTED_OUTPUT}
            IF    ${contains_output}
                Pass Execution    Execution contains '${EXPECTED_OUTPUT}'
            END
        END
        Sleep   ${RETRY_INTERVAL}
    END
    Fail    Alpine service did not return the expected output after ${MAX_RETRIES} retries


*** Keywords ***
Cleanup Alpine Service Resources
    [Documentation]    Best-effort cleanup of service and logs created by this suite.
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}?all=true    expected_status=ANY
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=ANY

Prepare Alpine Service File
    [Documentation]    Build the alpine-based service file from the cowsay template, swapping in the
    ...    alpine image and a busybox-compatible POSIX sh script.
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Set Service File VO    ${service_content}

    # Extract the inner dictionary (remove 'functions', 'oscar' and 'robot-oscar-cluster')
    VAR    ${modified_content}=    ${service_content}[functions][oscar][0][robot-oscar-cluster]

    # Alpine does not ship cowsay or bash: echo a marker and cat the input using busybox sh
    ${script_value}=    Catenate
    ...    \#!/bin/sh\n\ncat \"$INPUT_FILE_PATH\"\n
    Set To Dictionary    ${modified_content}    image=${ALPINE_IMAGE}
    Set To Dictionary    ${modified_content}    script=${script_value}
    Set To Dictionary    ${modified_content}    name=${SERVICE_NAME}
    ${input_entries}=    Get From Dictionary    ${modified_content}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${SERVICE_NAME}/input
    ${output_entries}=    Get From Dictionary    ${modified_content}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${SERVICE_NAME}/output
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${ALPINE_SERVICE_FILE}    ${service_content_json}

Wait For Alpine Service Ready
    [Documentation]    Polls the service endpoint until the service reports a ready state or the timeout expires.
    ${timeout}=    Set Variable If    '${LOCAL_TESTING}'=='True'    180s    210s
    ${interval}=   Set Variable    5s
    Wait Until Keyword Succeeds    ${timeout}    ${interval}    Alpine Service Should Be Ready

Alpine Service Should Be Ready
    [Documentation]    Asserts that the service status indicates readiness.
    ${response}=    GET With Defaults   url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=200
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${status}=    Evaluate    (lambda d: d.get('status') if not isinstance(d.get('status'), dict) else d['status'].get('state') or d['status'].get('phase') or d['status'].get('condition'))(${payload})    json
    ${ready}=    Evaluate    str(${status}).lower() in ("ready","running","available","succeeded") or bool(${payload}.get('ready')) or bool(${payload}.get('token'))    json
    Should Be True    ${ready}    Service not ready yet (status=${status})
