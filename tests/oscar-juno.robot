*** Settings ***
Documentation       Deploy JUNO (Jupyter) as an exposed OSCAR service and verify the endpoint is reachable.

Resource            ${CURDIR}/../resources/files.resource
Resource            ${CURDIR}/../resources/api_call.resource
Resource            ${CURDIR}/../resources/service.resource
Resource            ${CURDIR}/../${AUTHENTICATION_PROCESS}

Suite Setup         Run Keywords    Check Valid OIDC Token    AND    Assign Random Service Name    AND    Assign Random String
Suite Teardown      Cleanup Juno Suite


*** Variables ***
${SERVICE_BASE}             robot-test-juno
${SERVICE_NAME}             ${SERVICE_BASE}
${JUNO_SERVICE_FILE}        ${DATA_DIR}/juno-expose.yaml
${JUNO_SCRIPT_FILE}         ${DATA_DIR}/juno-script.sh
${GENERATED_SERVICE_FILE}   ${DATA_DIR}/juno_service_file.json
${JUPYTER_TOKEN}            junoroot


*** Test Cases ***
OSCAR Deploy Juno Exposed Service
    [Documentation]    Create Juno service from FDL and wait until OSCAR reports it as ready.
    Create Private Mount Bucket
    Prepare Juno Service File
    ${body}=    Get File    ${GENERATED_SERVICE_FILE}
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    Wait For Service Ready

OSCAR Juno Exposed Endpoint Is Reachable
    [Documentation]    Polls the exposed Jupyter endpoint and validates it responds.
    Wait Until Keyword Succeeds    36x    10s    Check Juno Exposed Endpoint


*** Keywords ***
Prepare Juno Service File
    [Documentation]    Build a deployable JSON payload from Juno FDL with random service name.
    ${service_content}=    Get File    ${JUNO_SERVICE_FILE}
    ${service_content}=    Set Service File VO    ${service_content}
    ${script_content}=    Get File    ${JUNO_SCRIPT_FILE}
    ${service_content}=    Set Service File Script    ${service_content}    ${script_content}

    ${oscar_list}=    Get From Dictionary    ${service_content}[functions]    oscar
    ${first_service_item}=    Get From List    ${oscar_list}    0
    ${service_keys}=    Get Dictionary Keys    ${first_service_item}
    ${cluster_key}=    Get From List    ${service_keys}    0
    ${service_spec}=    Get From Dictionary    ${first_service_item}    ${cluster_key}

    Set To Dictionary    ${service_spec}    name=${SERVICE_NAME}
    ${environment}=    Get From Dictionary    ${service_spec}    environment
    ${variables}=    Get From Dictionary    ${environment}    variables
    Set To Dictionary    ${variables}    JHUB_BASE_URL=/system/services/${SERVICE_NAME}/exposed
    Set To Dictionary    ${variables}    OSCAR_ENDPOINT=${OSCAR_ENDPOINT}
    ${secrets}=    Get From Dictionary    ${environment}    secrets
    ${jupyter_token}=    Set Variable    junoroot-${RANDOM_STRING}
    Set Suite Variable    ${JUPYTER_TOKEN}    ${jupyter_token}
    Set To Dictionary    ${secrets}    JUPYTER_TOKEN=${JUPYTER_TOKEN}
    ${mount}=    Get From Dictionary    ${service_spec}    mount
    Set To Dictionary    ${mount}    path=${BUCKET_NAME}

    Dump Service File To JSON File    ${service_content}    ${GENERATED_SERVICE_FILE}

Create Private Mount Bucket
    [Documentation]    Creates a private bucket dedicated to this test run.
    ${allowed_users}=    Create List
    ${bucket_payload}=    Create Dictionary    bucket_name=${BUCKET_NAME}    visibility=private    allowed_users=${allowed_users}
    ${body}=    Evaluate    json.dumps(${bucket_payload})    json
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/buckets    data=${body}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'

Check Juno Exposed Endpoint
    [Documentation]    Checks if Jupyter endpoint is reachable and contains expected markers.
    ${response}=    GET With Defaults
    ...    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}/exposed/lab?token=${JUPYTER_TOKEN}
    ...    expected_status=ANY
    Log    Status: ${response.status_code}
    ${status}=    Convert To Integer    ${response.status_code}
    Should Be True    ${status} == 200 or ${status} == 302

    ${body_text}=    Convert To String    ${response.text}
    ${has_jupyter}=    Run Keyword And Return Status
    ...    Should Match Regexp    ${body_text}    (?is).*(jupyter|jupyterlab|lab).*
    IF    not ${has_jupyter}
        ${location}=    Evaluate    dict($response.headers).get("Location", dict($response.headers).get("location", ""))    json
        Should Contain    ${location}    /system/services/${SERVICE_NAME}/exposed
    END

Wait For Service Ready
    [Documentation]    Polls the service endpoint until the service reports a ready state.
    Wait Until Keyword Succeeds    48x    5s    Service Should Be Ready

Service Should Be Ready
    [Documentation]    Asserts that service status is ready/running and expose config is available.
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=200
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${status}=    Evaluate    (lambda d: d.get('status') if not isinstance(d.get('status'), dict) else d['status'].get('state') or d['status'].get('phase') or d['status'].get('condition'))(${payload})    json
    ${ready}=    Evaluate    str(${status}).lower() in ("ready","running","available","succeeded") or bool(${payload}.get('ready')) or bool(${payload}.get('token'))    json
    Should Be True    ${ready}    Service not ready yet (status=${status})
    ${has_expose}=    Evaluate    bool(${payload}.get('expose') or ${payload}.get('exposed'))    json
    Should Be True    ${has_expose}    Service payload does not include expose metadata yet.

Cleanup Juno Suite
    [Documentation]    Deletes the deployed service and removes generated payload file.
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=ANY
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/${BUCKET_NAME}    expected_status=ANY
    Run Keyword And Ignore Error    Remove File    ${GENERATED_SERVICE_FILE}
