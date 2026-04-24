*** Settings ***
Documentation       Tests for OSCAR flows.

Resource            ${CURDIR}/../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../resources/files.resource
Resource            ${CURDIR}/../resources/api_call.resource
Resource            ${CURDIR}/../resources/service.resource

Library             yaml


Suite Setup         Run Keywords    Check Valid OIDC Token    AND    Assign Random Service Name


Suite Teardown      Clean Test Artifacts    True


*** Variables ***
${SERVICE_BASE}    node-red
${DATA_DIR}        ${CURDIR}/../data
${SERVICE_YAML}    ${DATA_DIR}/${SERVICE_BASE}.yaml


*** Test Cases ***
Refresh Token Exist
    ${exists}=    Run Keyword And Return Status    Variable Should Exist    ${REFRESH_TOKEN}
    IF  not ${exists}
        Set Refresh Token
    END

Create Node-RED Service
    [Documentation]    Create the Node-RED service from YAML definition
    [Tags]    create
    ${yaml_content}=    Get File    ${SERVICE_YAML}
    ${service_data}=    yaml.Safe Load    ${yaml_content}
    ${oscar_list}=    Get From Dictionary    ${service_data}[functions]    oscar
    ${first_service}=    Get From List    ${oscar_list}    0
    ${service_def}=    Get From Dictionary    ${first_service}    oscar-cluster
    Set To Dictionary    ${service_def}    name=${SERVICE_NAME}
    ${node_red_url}=    Set Variable    /system/services/${SERVICE_NAME}/exposed
    Set To Dictionary    ${service_def}[environment][variables]    NODE_RED_BASE_URL=${node_red_url}
    ${bucket_mnt}=    Set Variable    /mnt/${BUCKET_NAME}
    Set To Dictionary    ${service_def}[environment][variables]    NODE_RED_DIRECTORY=${bucket_mnt}
    Set To Dictionary    ${service_def}[mount]    path=${BUCKET_NAME}
    ${body}=    Evaluate    json.dumps(${service_def})    json
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Log    ${response.content}
    ${retry}=    Evaluate    (str(${response.status_code}) == '201' or str(${response.status_code}) == '409')

Check Node-RED Service Ready
    [Documentation]    Check that the Node-RED service is ready
    [Tags]    ready
    FOR    ${i}    IN RANGE    999
        ${status}=    Run Keyword And Return Status    Service Should Be Ready
        Exit For Loop If    ${status}
        Sleep    5s
    END

Verify Node-RED Service Response
    [Documentation]    Verify the Node-RED service responds correctly at /system/services/{service_name}/exposed/
    [Tags]    verify
    ${timeout}=    Set Variable If    '${LOCAL_TESTING}'=='True'    60s    90s
    ${interval}=   Set Variable    5s
    ${url}=    Set Variable    ${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}/exposed/
    Wait Until Keyword Succeeds    ${timeout}    ${interval}    GET With Defaults    url=${url}


Delete Node-RED Service
    [Documentation]    Delete the Node-RED service
    [Tags]    delete
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Delete Bucket
    [Documentation]    Delete the bucket used by the Node-RED service
    [Tags]    delete
    ${response}=    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/${BUCKET_NAME}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204


*** Keywords ***
Service Should Be Ready
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${status}=    Evaluate    (lambda d: d.get('status') if not isinstance(d.get('status'), dict) else d['status'].get('state') or d['status'].get('phase') or d['status'].get('condition'))(${payload})
    ${ready}=    Evaluate    str(${status}).lower() in ("ready","running","available","succeeded") or bool(${payload}.get('ready')) or bool(${payload}.get('token'))
    Should Be True    ${ready}    Service not ready yet (status=${status})

Service Returns Valid Response
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    Should Contain    ${payload}    name
    Should Be Equal    ${payload}[name]    ${SERVICE_NAME}