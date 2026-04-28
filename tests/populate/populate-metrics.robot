*** Settings ***
Documentation       Populate an OSCAR cluster with simple, exposed, and shared services for metrics.

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/api_call.resource
Resource            ${CURDIR}/../../resources/files.resource

Library             Collections
Library             OperatingSystem
Library             String

Suite Setup         Setup Populate Metrics Suite
Suite Teardown      Teardown Populate Metrics Suite


*** Variables ***
${POPULATE_SERVICE_PREFIX}          metrics-populate-simple
${POPULATE_EXPOSED_PREFIX}          metrics-populate-exposed
${POPULATE_SHARED_PREFIX}           metrics-populate-shared
${POPULATE_RUN_ID}                  ${EMPTY}
${POPULATE_SERVICE_COUNT}           4
${POPULATE_SYNC_INVOCATIONS}        2
${POPULATE_ASYNC_INVOCATIONS}       2
${POPULATE_EXPOSED_INVOCATIONS}     2
${POPULATE_SHARED_SYNC_INVOCATIONS}     1
${POPULATE_SHARED_ASYNC_INVOCATIONS}    1
${POPULATE_CLEANUP}                 ${False}
${POPULATE_DELETE_ONLY}             ${False}
${POPULATE_SERVICE_CPU}             0.5
${POPULATE_SERVICE_MEMORY}          256Mi
${POPULATE_EXPOSED_CPU}             0.5
${POPULATE_EXPOSED_MEMORY}          256Mi
${POPULATE_SERVICE_FILE}            ${DATA_DIR}/simple-test.yaml
${POPULATE_SERVICE_SCRIPT}          ${DATA_DIR}/simple-test-script.sh
${POPULATE_EXPOSED_SERVICE_FILE}    ${DATA_DIR}/expose_services/nginx_expose.yaml
${POPULATE_EXPOSED_SCRIPT}          ${DATA_DIR}/expose_services/nginxscript.sh
${POPULATE_PAYLOAD_FILE}            ${DATA_DIR}/simple-test-input.payload
${POPULATE_GENERATED_DIR}           ${DATA_DIR}/populate
${POPULATE_EXPOSED_USER_INDEX}      1
${POPULATE_SHARED_OWNER_INDEX}      0
${POPULATE_SHARED_OTHER_INDEX}      1
${POPULATE_SERVICE_TIMEOUT}         240s
${POPULATE_SERVICE_RETRY_INTERVAL}  5s
${POPULATE_INVOKE_TIMEOUT}          120s
${POPULATE_INVOKE_RETRY_INTERVAL}   5s
${POPULATE_ASYNC_SETTLE_TIME}       30s


*** Test Cases ***
Delete Populate Services If Requested
    [Documentation]    Remove the services for POPULATE_RUN_ID and stop when running in delete-only mode.
    [Tags]    populate    cleanup
    Skip If    not ${POPULATE_DELETE_ONLY}
    Delete Populate Services

Create Populate Services As Multiple Users
    [Documentation]    Create simple-test and exposed services split between oscaruser00 and oscaruser01.
    [Tags]    populate    create
    Skip If    ${POPULATE_DELETE_ONLY}
    FOR    ${index}    IN RANGE    ${POPULATE_SERVICE_COUNT}
        ${service_name}=    Populate Service Name For Index    ${index}
        ${headers}=    Populate Headers For Index    ${index}
        Prepare Populate Service File    ${index}    ${service_name}
        ${service_file}=    Populate Service File For Index    ${index}
        ${body}=    Get File    ${service_file}
        ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${headers}
        Log    ${response.content}
        Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    END
    ${exposed_service_name}=    Populate Exposed Service Name
    ${exposed_headers}=    Populate Headers For Index    ${POPULATE_EXPOSED_USER_INDEX}
    Prepare Populate Exposed Service File    ${exposed_service_name}
    ${exposed_service_file}=    Populate Exposed Service File
    ${body}=    Get File    ${exposed_service_file}
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${exposed_headers}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    ${shared_service_name}=    Populate Shared Service Name
    ${shared_owner_headers}=    Populate Headers For Index    ${POPULATE_SHARED_OWNER_INDEX}
    Prepare Populate Shared Service File    ${shared_service_name}
    ${shared_service_file}=    Populate Shared Service File
    ${body}=    Get File    ${shared_service_file}
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${shared_owner_headers}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'

Wait For Populate Services Ready
    [Documentation]    Wait until every populated service can be invoked.
    [Tags]    populate    ready
    Skip If    ${POPULATE_DELETE_ONLY}
    FOR    ${index}    IN RANGE    ${POPULATE_SERVICE_COUNT}
        ${service_name}=    Populate Service Name For Index    ${index}
        ${headers}=    Populate Headers For Index    ${index}
        Wait Until Keyword Succeeds
        ...    ${POPULATE_SERVICE_TIMEOUT}
        ...    ${POPULATE_SERVICE_RETRY_INTERVAL}
        ...    Populate Service Should Be Ready
        ...    ${service_name}
        ...    ${headers}
    END
    ${exposed_service_name}=    Populate Exposed Service Name
    ${exposed_headers}=    Populate Headers For Index    ${POPULATE_EXPOSED_USER_INDEX}
    Wait Until Keyword Succeeds
    ...    ${POPULATE_SERVICE_TIMEOUT}
    ...    ${POPULATE_SERVICE_RETRY_INTERVAL}
    ...    Populate Service Should Be Ready
    ...    ${exposed_service_name}
    ...    ${exposed_headers}
    Wait Until Keyword Succeeds
    ...    ${POPULATE_SERVICE_TIMEOUT}
    ...    ${POPULATE_SERVICE_RETRY_INTERVAL}
    ...    Populate Exposed Service Should Respond
    ${shared_service_name}=    Populate Shared Service Name
    ${shared_owner_headers}=    Populate Headers For Index    ${POPULATE_SHARED_OWNER_INDEX}
    ${shared_other_headers}=    Populate Headers For Index    ${POPULATE_SHARED_OTHER_INDEX}
    Wait Until Keyword Succeeds
    ...    ${POPULATE_SERVICE_TIMEOUT}
    ...    ${POPULATE_SERVICE_RETRY_INTERVAL}
    ...    Populate Service Should Be Ready
    ...    ${shared_service_name}
    ...    ${shared_owner_headers}
    Populate Shared Service Should Be Visible To Other User
    ...    ${shared_service_name}
    ...    ${shared_other_headers}

Invoke Populate Services Synchronously
    [Documentation]    Send sync requests to every populated service using the owning user's credentials.
    [Tags]    populate    sync
    Skip If    ${POPULATE_DELETE_ONLY}
    ${body}=    Get File    ${POPULATE_PAYLOAD_FILE}
    FOR    ${index}    IN RANGE    ${POPULATE_SERVICE_COUNT}
        ${service_name}=    Populate Service Name For Index    ${index}
        ${headers}=    Populate Headers For Index    ${index}
        FOR    ${invocation}    IN RANGE    ${POPULATE_SYNC_INVOCATIONS}
            Wait Until Keyword Succeeds
            ...    ${POPULATE_INVOKE_TIMEOUT}
            ...    ${POPULATE_INVOKE_RETRY_INTERVAL}
            ...    Invoke Populate Service Synchronously
            ...    ${service_name}
            ...    ${headers}
            ...    ${body}
        END
    END

Invoke Populate Services Asynchronously
    [Documentation]    Submit async jobs to every populated service using the owning user's credentials.
    [Tags]    populate    async
    Skip If    ${POPULATE_DELETE_ONLY}
    ${body}=    Get File    ${POPULATE_PAYLOAD_FILE}
    FOR    ${index}    IN RANGE    ${POPULATE_SERVICE_COUNT}
        ${service_name}=    Populate Service Name For Index    ${index}
        ${headers}=    Populate Headers For Index    ${index}
        FOR    ${invocation}    IN RANGE    ${POPULATE_ASYNC_INVOCATIONS}
            Invoke Populate Service Asynchronously    ${service_name}    ${headers}    ${body}
        END
    END
    Sleep    ${POPULATE_ASYNC_SETTLE_TIME}

Invoke Populate Exposed Service
    [Documentation]    Send requests to the exposed nginx service to increase exposed request metrics.
    [Tags]    populate    exposed
    Skip If    ${POPULATE_DELETE_ONLY}
    FOR    ${invocation}    IN RANGE    ${POPULATE_EXPOSED_INVOCATIONS}
        Invoke Populate Exposed Service Once
    END

Invoke Shared Populate Service As Both Users
    [Documentation]    Invoke one shared service as both oscaruser00 and oscaruser01.
    [Tags]    populate    shared    sync    async
    Skip If    ${POPULATE_DELETE_ONLY}
    ${body}=    Get File    ${POPULATE_PAYLOAD_FILE}
    ${service_name}=    Populate Shared Service Name
    ${owner_headers}=    Populate Headers For Index    ${POPULATE_SHARED_OWNER_INDEX}
    ${other_headers}=    Populate Headers For Index    ${POPULATE_SHARED_OTHER_INDEX}
    FOR    ${headers}    IN    ${owner_headers}    ${other_headers}
        FOR    ${invocation}    IN RANGE    ${POPULATE_SHARED_SYNC_INVOCATIONS}
            Wait Until Keyword Succeeds
            ...    ${POPULATE_INVOKE_TIMEOUT}
            ...    ${POPULATE_INVOKE_RETRY_INTERVAL}
            ...    Invoke Populate Service Synchronously
            ...    ${service_name}
            ...    ${headers}
            ...    ${body}
        END
        FOR    ${invocation}    IN RANGE    ${POPULATE_SHARED_ASYNC_INVOCATIONS}
            Invoke Populate Service Asynchronously    ${service_name}    ${headers}    ${body}
        END
    END


*** Keywords ***
Setup Populate Metrics Suite
    [Documentation]    Authenticate both users, create run context, and prepare generated file storage.
    Checks Valids OIDC Token
    Create Directory    ${POPULATE_GENERATED_DIR}
    ${run_id}=    Set Variable    ${POPULATE_RUN_ID}
    IF    '${run_id}' == ''
        ${run_id}=    Evaluate    ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))    modules=random,string
    END
    Set Suite Variable    ${POPULATE_RUN_ID}    ${run_id}
    ${last_index}=    Evaluate    int($POPULATE_SERVICE_COUNT) - 1
    ${last_index_text}=    Evaluate    f"{int($last_index):02d}"
    Log To Console    OSCAR populate run id: ${POPULATE_RUN_ID}
    Log To Console    OSCAR populate services: ${POPULATE_SERVICE_PREFIX}-${POPULATE_RUN_ID}-00 .. ${POPULATE_SERVICE_PREFIX}-${POPULATE_RUN_ID}-${last_index_text}
    Log To Console    OSCAR populate exposed service: ${POPULATE_EXPOSED_PREFIX}-${POPULATE_RUN_ID}
    Log To Console    OSCAR populate shared service: ${POPULATE_SHARED_PREFIX}-${POPULATE_RUN_ID}
    Variable Should Exist    ${HEADERS2}    This suite needs a secondary user. Use variables/.env-auth-keycloak-oscarusers.yaml or another auth file that defines KEYCLOAK_USERNAME_AUX.

Teardown Populate Metrics Suite
    [Documentation]    Optionally remove services and always remove generated service JSON files.
    IF    ${POPULATE_CLEANUP} and not ${POPULATE_DELETE_ONLY}
        Delete Populate Services
    END
    Remove Populate Generated Files

Prepare Populate Service File
    [Documentation]    Generate a simple-test service JSON body for one populated service.
    [Arguments]    ${index}    ${service_name}
    ${yaml_content}=    Get File    ${POPULATE_SERVICE_FILE}
    ${service_content}=    Set Populate Service File VO    ${yaml_content}
    ${modified_content}=    Set Variable    ${service_content}[functions][oscar][0][oscar-cluster]
    ${script}=    Get File    ${POPULATE_SERVICE_SCRIPT}
    Set To Dictionary    ${modified_content}    script=${script}
    Set To Dictionary    ${modified_content}    name=${service_name}
    Set To Dictionary    ${modified_content}    cpu=${POPULATE_SERVICE_CPU}
    Set To Dictionary    ${modified_content}    memory=${POPULATE_SERVICE_MEMORY}
    Set To Dictionary    ${modified_content}    isolation_level=SERVICE
    ${input_entries}=    Get From Dictionary    ${modified_content}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${service_name}/input
    ${output_entries}=    Get From Dictionary    ${modified_content}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${service_name}/output
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    ${service_file}=    Populate Service File For Index    ${index}
    Create File    ${service_file}    ${service_content_json}

Prepare Populate Exposed Service File
    [Documentation]    Generate the exposed nginx service JSON body for this run.
    [Arguments]    ${service_name}
    ${yaml_content}=    Get File    ${POPULATE_EXPOSED_SERVICE_FILE}
    ${service_content}=    Set Populate Exposed Service File VO    ${yaml_content}
    ${modified_content}=    Set Variable    ${service_content}[functions][oscar][0][oscar-cluster]
    ${script}=    Get File    ${POPULATE_EXPOSED_SCRIPT}
    Set To Dictionary    ${modified_content}    script=${script}
    Set To Dictionary    ${modified_content}    name=${service_name}
    Set To Dictionary    ${modified_content}    cpu=${POPULATE_EXPOSED_CPU}
    Set To Dictionary    ${modified_content}    memory=${POPULATE_EXPOSED_MEMORY}
    Set To Dictionary    ${modified_content}    isolation_level=SERVICE
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    ${service_file}=    Populate Exposed Service File
    Create File    ${service_file}    ${service_content_json}

Prepare Populate Shared Service File
    [Documentation]    Generate a simple-test service JSON body visible to both users.
    [Arguments]    ${service_name}
    ${yaml_content}=    Get File    ${POPULATE_SERVICE_FILE}
    ${service_content}=    Set Populate Service File VO    ${yaml_content}
    ${modified_content}=    Set Variable    ${service_content}[functions][oscar][0][oscar-cluster]
    ${script}=    Get File    ${POPULATE_SERVICE_SCRIPT}
    Set To Dictionary    ${modified_content}    script=${script}
    Set To Dictionary    ${modified_content}    name=${service_name}
    Set To Dictionary    ${modified_content}    cpu=${POPULATE_SERVICE_CPU}
    Set To Dictionary    ${modified_content}    memory=${POPULATE_SERVICE_MEMORY}
    Set To Dictionary    ${modified_content}    isolation_level=SERVICE
    Set To Dictionary    ${modified_content}    visibility=restricted
    ${allowed_users}=    Create List    ${USER}    ${OTHER_USER}
    Set To Dictionary    ${modified_content}    allowed_users=${allowed_users}
    ${input_entries}=    Get From Dictionary    ${modified_content}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${service_name}/input
    ${output_entries}=    Get From Dictionary    ${modified_content}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${service_name}/output
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    ${service_file}=    Populate Shared Service File
    Create File    ${service_file}    ${service_content_json}

Set Populate Service File VO
    [Documentation]    Load a service YAML string and add the VO field expected by OSCAR.
    [Arguments]    ${service_content}
    ${service_content}=    yaml.Safe Load    ${service_content}
    Set To Dictionary    ${service_content}[functions][oscar][0][oscar-cluster]    vo=${VO}
    RETURN    ${service_content}

Set Populate Exposed Service File VO
    [Documentation]    Load the exposed service YAML string and add the VO field expected by OSCAR.
    [Arguments]    ${service_content}
    ${service_content}=    yaml.Safe Load    ${service_content}
    Set To Dictionary    ${service_content}[functions][oscar][0][oscar-cluster]    vo=${VO}
    RETURN    ${service_content}

Populate Service Name For Index
    [Documentation]    Return the deterministic service name for an index in this run.
    [Arguments]    ${index}
    ${index_text}=    Evaluate    f"{int($index):02d}"
    ${service_name}=    Set Variable    ${POPULATE_SERVICE_PREFIX}-${POPULATE_RUN_ID}-${index_text}
    RETURN    ${service_name}

Populate Exposed Service Name
    [Documentation]    Return the deterministic exposed service name for this run.
    ${service_name}=    Set Variable    ${POPULATE_EXPOSED_PREFIX}-${POPULATE_RUN_ID}
    RETURN    ${service_name}

Populate Shared Service Name
    [Documentation]    Return the deterministic shared service name for this run.
    ${service_name}=    Set Variable    ${POPULATE_SHARED_PREFIX}-${POPULATE_RUN_ID}
    RETURN    ${service_name}

Populate Service File For Index
    [Documentation]    Return the generated JSON path for an index in this run.
    [Arguments]    ${index}
    ${service_name}=    Populate Service Name For Index    ${index}
    ${service_file}=    Set Variable    ${POPULATE_GENERATED_DIR}/${service_name}.json
    RETURN    ${service_file}

Populate Exposed Service File
    [Documentation]    Return the generated JSON path for the exposed service in this run.
    ${service_name}=    Populate Exposed Service Name
    ${service_file}=    Set Variable    ${POPULATE_GENERATED_DIR}/${service_name}.json
    RETURN    ${service_file}

Populate Shared Service File
    [Documentation]    Return the generated JSON path for the shared service in this run.
    ${service_name}=    Populate Shared Service Name
    ${service_file}=    Set Variable    ${POPULATE_GENERATED_DIR}/${service_name}.json
    RETURN    ${service_file}

Populate Headers For Index
    [Documentation]    Alternate services between oscaruser00 and oscaruser01.
    [Arguments]    ${index}
    ${mod}=    Evaluate    int($index) % 2
    ${headers}=    Set Variable If    ${mod} == 0    ${HEADERS}    ${HEADERS2}
    RETURN    ${headers}

Populate Service Should Be Ready
    [Documentation]    Assert that a populated service status indicates readiness.
    [Arguments]    ${service_name}    ${headers}
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=200    headers=${headers}
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${status}=    Evaluate
    ...    (lambda d: d.get("status") if not isinstance(d.get("status"), dict) else d["status"].get("state") or d["status"].get("phase") or d["status"].get("condition"))(${payload})
    ...    json
    ${ready}=    Evaluate
    ...    str(${status}).lower() in ("ready","running","available","succeeded") or bool(${payload}.get("ready")) or bool(${payload}.get("token"))
    ...    json
    Should Be True    ${ready}    Service ${service_name} not ready yet (status=${status})

Populate Exposed Service Should Respond
    [Documentation]    Assert that the exposed service endpoint is reachable.
    ${service_name}=    Populate Exposed Service Name
    ${headers}=    Populate Headers For Index    ${POPULATE_EXPOSED_USER_INDEX}
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}/exposed    headers=${headers}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    Welcome to nginx

Populate Shared Service Should Be Visible To Other User
    [Documentation]    Assert that the non-owner user can read the shared service.
    [Arguments]    ${service_name}    ${headers}
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=200    headers=${headers}
    Log    ${response.content}
    Should Contain    ${response.content}    "name":"${service_name}"

Invoke Populate Service Synchronously
    [Documentation]    Invoke one service synchronously and require a successful response.
    [Arguments]    ${service_name}    ${headers}    ${body}
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/run/${service_name}    data=${body}    headers=${headers}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200

Invoke Populate Service Asynchronously
    [Documentation]    Submit one async job for a service.
    [Arguments]    ${service_name}    ${headers}    ${body}
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/job/${service_name}    data=${body}    headers=${headers}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

Invoke Populate Exposed Service Once
    [Documentation]    Invoke the exposed nginx service once.
    ${service_name}=    Populate Exposed Service Name
    ${headers}=    Populate Headers For Index    ${POPULATE_EXPOSED_USER_INDEX}
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}/exposed    headers=${headers}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    Welcome to nginx

Delete Populate Services
    [Documentation]    Remove populated service jobs and services for both users.
    FOR    ${index}    IN RANGE    ${POPULATE_SERVICE_COUNT}
        ${service_name}=    Populate Service Name For Index    ${index}
        ${headers}=    Populate Headers For Index    ${index}
        ${jobs_response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${service_name}?all=true    expected_status=ANY    headers=${headers}
        Log    Delete jobs for ${service_name}: ${jobs_response.status_code}
        ${service_response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=ANY    headers=${headers}
        Log    Delete service ${service_name}: ${service_response.status_code}
        Should Be True
        ...    '${service_response.status_code}' in ['204', '404']
        ...    msg=Unexpected delete status for ${service_name}: ${service_response.status_code}
    END
    ${exposed_service_name}=    Populate Exposed Service Name
    ${exposed_headers}=    Populate Headers For Index    ${POPULATE_EXPOSED_USER_INDEX}
    ${exposed_response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${exposed_service_name}    expected_status=ANY    headers=${exposed_headers}
    Log    Delete exposed service ${exposed_service_name}: ${exposed_response.status_code}
    Should Be True
    ...    '${exposed_response.status_code}' in ['204', '404']
    ...    msg=Unexpected delete status for ${exposed_service_name}: ${exposed_response.status_code}
    ${shared_service_name}=    Populate Shared Service Name
    ${shared_owner_headers}=    Populate Headers For Index    ${POPULATE_SHARED_OWNER_INDEX}
    ${shared_jobs_response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${shared_service_name}?all=true    expected_status=ANY    headers=${shared_owner_headers}
    Log    Delete jobs for shared service ${shared_service_name}: ${shared_jobs_response.status_code}
    ${shared_response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${shared_service_name}    expected_status=ANY    headers=${shared_owner_headers}
    Log    Delete shared service ${shared_service_name}: ${shared_response.status_code}
    Should Be True
    ...    '${shared_response.status_code}' in ['204', '404']
    ...    msg=Unexpected delete status for ${shared_service_name}: ${shared_response.status_code}

Remove Populate Generated Files
    [Documentation]    Remove temporary generated service JSON files.
    FOR    ${index}    IN RANGE    ${POPULATE_SERVICE_COUNT}
        ${service_file}=    Populate Service File For Index    ${index}
        Run Keyword And Ignore Error    Remove File    ${service_file}
    END
    ${exposed_service_file}=    Populate Exposed Service File
    Run Keyword And Ignore Error    Remove File    ${exposed_service_file}
    ${shared_service_file}=    Populate Shared Service File
    Run Keyword And Ignore Error    Remove File    ${shared_service_file}
