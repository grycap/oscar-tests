*** Settings ***
Documentation       Tests for the OSCAR API /system/services/{name}/deployment and deployment/logs endpoints.

Library             Collections
Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/api_call.resource
Resource            ${CURDIR}/../../resources/service.resource

Suite Setup         Run Keywords    Check Valid OIDC Token    AND    Initialize Deployment Test Names
Suite Teardown      Cleanup Deployment Test Artifacts


*** Variables ***
${SERVICE_TIMEOUT}          180s
${SERVICE_RETRY_INTERVAL}   10s
${DEPLOYMENT_SERVICE_FILE}  ${DATA_DIR}/deployment_service_file.json


*** Test Cases ***
OSCAR Create Service For Deployment
    [Documentation]    Create a service to query its deployment status and logs.
    [Tags]    create
    ${exists}=    Service Exists    ${SERVICE_NAME}
    IF    not ${exists}
        Prepare Deployment Service File
        ${body}=    Get File    ${DEPLOYMENT_SERVICE_FILE}
        ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
        Log    ${response.content}
        Should Be True    '${response.status_code}' == '201' or '${response.status_code}' == '409'
    END
    Wait Until Keyword Succeeds
    ...    ${SERVICE_TIMEOUT}
    ...    ${SERVICE_RETRY_INTERVAL}
    ...    Service Should Be Ready
    ...    ${SERVICE_NAME}

OSCAR Get Deployment Status
    [Documentation]    Get deployment status and validate the response contract.
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}/deployment
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    Validate Deployment Status    ${response}

OSCAR Get Deployment Logs
    [Documentation]    Get deployment logs and validate the response contract.
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}/deployment/logs
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    Validate Deployment Logs    ${response}

OSCAR Deployment Status Not Found
    [Documentation]    Query deployment status for a non-existent service.
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/nonexistent-service/deployment    expected_status=ANY
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '403' or '${response.status_code}' == '404'

OSCAR Deployment Logs Not Found
    [Documentation]    Query deployment logs for a non-existent service.
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/nonexistent-service/deployment/logs    expected_status=ANY
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '403' or '${response.status_code}' == '404'


*** Keywords ***
Initialize Deployment Test Names
    [Documentation]    Generate a unique service name for this suite run.
    ${suffix}=    Evaluate    ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))    modules=random,string
    Set Suite Variable    ${SERVICE_NAME}    robot-deploy-${suffix}

Prepare Deployment Service File
    [Documentation]    Prepare a lightweight service for deployment testing.
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Set Service File VO    ${service_content}
    VAR    ${modified_content}=    ${service_content}[functions][oscar][0][robot-oscar-cluster]
    ${script_value}=    Catenate
    ...    \#!/bin/sh\n\nif [ \"$INPUT_TYPE\" = \"json\" ]\nthen\n
    ...    jq '.message' \"$INPUT_FILE_PATH\" -r | /usr/games/cowsay\nelse\n
    ...    cat \"$INPUT_FILE_PATH\" | /usr/games/cowsay\nfi\n\
    Set To Dictionary    ${modified_content}    script=${script_value}
    Set To Dictionary    ${modified_content}    name=${SERVICE_NAME}
    Set To Dictionary    ${modified_content}    cpu=0.5
    Set To Dictionary    ${modified_content}    memory=256Mi
    ${input_entries}=    Get From Dictionary    ${modified_content}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${SERVICE_NAME}/input
    ${output_entries}=    Get From Dictionary    ${modified_content}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${SERVICE_NAME}/output
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${DEPLOYMENT_SERVICE_FILE}    ${service_content_json}

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

Validate Deployment Status
    [Documentation]    Validate the deployment status response contract.
    [Arguments]    ${response}
    ${payload}=    Evaluate    json.loads($response.content)    json
    Dictionary Should Contain Key    ${payload}    state
    Dictionary Should Contain Key    ${payload}    active_instances
    Dictionary Should Contain Key    ${payload}    affected_instances
    Dictionary Should Contain Key    ${payload}    resource_kind
    ${state}=    Get From Dictionary    ${payload}    state
    Should Be True    $state in ("pending","ready","degraded","failed","unavailable")
    ...    msg=Unexpected deployment state: ${state}
    ${active}=    Get From Dictionary    ${payload}    active_instances
    Should Be True    isinstance($active, (int, float)) and $active >= 0
    ...    msg=Expected active_instances to be a non-negative number

Validate Deployment Logs
    [Documentation]    Validate the deployment logs response contract.
    [Arguments]    ${response}
    ${payload}=    Evaluate    json.loads($response.content)    json
    Dictionary Should Contain Key    ${payload}    service_name
    Dictionary Should Contain Key    ${payload}    available
    Dictionary Should Contain Key    ${payload}    entries
    Should Be Equal As Strings    ${payload["service_name"]}    ${SERVICE_NAME}
    ${entries}=    Get From Dictionary    ${payload}    entries
    Should Be True    isinstance($entries, list)
    ...    msg=Expected entries to be a JSON array

Cleanup Deployment Test Artifacts
    [Documentation]    Remove the service and temp files created by this suite.
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}?all=true
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    Run Keyword And Ignore Error    Remove File    ${DEPLOYMENT_SERVICE_FILE}
