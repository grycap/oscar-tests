*** Settings ***
Documentation       Tests for OSCAR /system/federation/{serviceName} endpoints.
...                 Creates services with star and mesh topologies on the same cluster
...                 using logical cluster IDs and a clusters map pointing to the same endpoint.

Library             Collections
Library             String
Library             OperatingSystem
Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/api_call.resource
Resource            ${CURDIR}/../../resources/service.resource

Suite Setup         Run Keywords
...                     Check Valid OIDC Token
...                     AND    Initialize Federation Test Names
...                     AND    Create Prerequisite Services
Suite Teardown      Cleanup Federation Test Artifacts


*** Variables ***
${SERVICE_TIMEOUT}          180s
${SERVICE_RETRY_INTERVAL}   10s
${FED_STAR_FILE}            ${DATA_DIR}/federation_star.json
${FED_MESH_FILE}            ${DATA_DIR}/federation_mesh.json
@{EMPTY_LIST}=


*** Test Cases ***
Get Federation From NonFederated Service
    [Documentation]    GET federation on a service without federation should return 200 with "topology":"none".
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/federation/${NON_FED_SVC}
    ...    headers=${HEADERS}    expected_status=ANY    verify=${SSL_VERIFY}
    Should Be Equal As Strings    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    Should Be Equal    ${payload}[topology]    none
    Should Be Equal    ${payload}[members]    ${NONE}

Create Star Federation Service
    [Documentation]    Create a service with star topology federation (no members yet).
    ${json}=    Build Federation Service Body    ${MAIN_SVC}    star
    Create File    ${FED_STAR_FILE}    ${json}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    data=${json}
    ...    headers=${HEADERS}    expected_status=ANY    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201
    Wait Until Keyword Succeeds
    ...    ${SERVICE_TIMEOUT}
    ...    ${SERVICE_RETRY_INTERVAL}
    ...    Service Should Be Ready
    ...    ${MAIN_SVC}

Get Federation Star
    [Documentation]    GET federation on the star main service and verify the contract.
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/federation/${MAIN_SVC}
    ...    headers=${HEADERS}    expected_status=200    verify=${SSL_VERIFY}
    Should Be Equal As Strings    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    Dictionary Should Contain Key    ${payload}    topology
    Dictionary Should Contain Key    ${payload}    members
    Should Be Equal    ${payload}[topology]    star
    Should Be Equal    ${payload}[members]    ${NONE}

Add Federation Members To Star
    [Documentation]    POST federation to add worker services as members.
    ${clusters}=    Get Clusters Config
    ${members}=    Evaluate
    ...    [{"type": "oscar", "cluster_id": "${CLUSTER_ID_A}", "service_name": "${WORKER1_SVC}", "priority": 0}, {"type": "oscar", "cluster_id": "${CLUSTER_ID_B}", "service_name": "${WORKER2_SVC}", "priority": 1}]
    ${body}=    Create Dictionary    members=${members}    clusters=${clusters}
    ${data}=    Evaluate    json.dumps(${body})    json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/federation/${MAIN_SVC}    data=${data}
    ...    headers=${HEADERS}    expected_status=ANY    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200

Get Federation Star With Members
    [Documentation]    GET federation after adding members. Verify both workers appear.
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/federation/${MAIN_SVC}
    ...    headers=${HEADERS}    expected_status=200    verify=${SSL_VERIFY}
    Should Be Equal As Strings    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    Should Be Equal    ${payload}[topology]    star
    ${members}=    Get From Dictionary    ${payload}    members
    Should Not Be Equal    ${members}    ${NONE}
    ${member_names}=    Evaluate    [m["service_name"] for m in $members]
    List Should Contain Value    ${member_names}    ${WORKER1_SVC}
    List Should Contain Value    ${member_names}    ${WORKER2_SVC}

Update Federation Priority
    [Documentation]    PUT federation to update the priority of an existing member.
    ${members}=    Evaluate
    ...    [{"type": "oscar", "cluster_id": "${CLUSTER_ID_A}", "service_name": "${WORKER1_SVC}"}]
    ${update}=    Evaluate
    ...    [{"type": "oscar", "cluster_id": "${CLUSTER_ID_A}", "service_name": "${WORKER1_SVC}", "priority": 10}]
    ${body}=    Create Dictionary    members=${members}    update=${update}
    ${data}=    Evaluate    json.dumps(${body})    json
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/federation/${MAIN_SVC}    data=${data}
    ...    headers=${HEADERS}    expected_status=ANY    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200

Get Federation Star After Update
    [Documentation]    GET federation and verify the priority was updated.
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/federation/${MAIN_SVC}
    ...    headers=${HEADERS}    expected_status=200    verify=${SSL_VERIFY}
    Should Be Equal As Strings    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${members}=    Get From Dictionary    ${payload}    members
    ${priorities}=    Evaluate    {m["service_name"]: m["priority"] for m in $members}
    Should Be Equal As Integers    ${priorities}[${WORKER1_SVC}]    10
    Should Be Equal As Integers    ${priorities}[${WORKER2_SVC}]    1

Remove Federation Member
    [Documentation]    DELETE federation to remove a member (delete=false, keep the service).
    ${members}=    Evaluate
    ...    [{"type": "oscar", "cluster_id": "${CLUSTER_ID_A}", "service_name": "${WORKER1_SVC}"}]
    ${body}=    Create Dictionary    members=${members}    delete=${False}
    ${data}=    Evaluate    json.dumps(${body})    json
    ${headers}=    Create Dictionary    &{HEADERS}
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/federation/${MAIN_SVC}
    ...    data=${data}    headers=${headers}    expected_status=ANY
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200

Get Federation Star After Removal
    [Documentation]    GET federation and verify the removed member is gone.
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/federation/${MAIN_SVC}
    ...    headers=${HEADERS}    expected_status=200    verify=${SSL_VERIFY}
    Should Be Equal As Strings    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${members}=    Get From Dictionary    ${payload}    members
    ${member_names}=    Evaluate    [m["service_name"] for m in $members] if $members else []
    List Should Not Contain Value    ${member_names}    ${WORKER1_SVC}
    List Should Contain Value    ${member_names}    ${WORKER2_SVC}

Teardown Star Federation Service
    [Documentation]    Delete the main star service to free MinIO buckets for the mesh test.
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${MAIN_SVC}
    ...    headers=${HEADERS}    expected_status=ANY    verify=${SSL_VERIFY}
    Should Be Equal As Strings    ${response.status_code}    204

Create Mesh Federation Service
    [Documentation]    Create a service with mesh topology federation.
    ${json}=    Build Federation Service Body    ${MESH_SVC}    mesh
    Create File    ${FED_MESH_FILE}    ${json}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    data=${json}
    ...    headers=${HEADERS}    expected_status=ANY    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201
    Wait Until Keyword Succeeds
    ...    ${SERVICE_TIMEOUT}
    ...    ${SERVICE_RETRY_INTERVAL}
    ...    Service Should Be Ready
    ...    ${MESH_SVC}

Get Federation Mesh
    [Documentation]    GET federation on the mesh service.
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/federation/${MESH_SVC}
    ...    headers=${HEADERS}    expected_status=200    verify=${SSL_VERIFY}
    Should Be Equal As Strings    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    Should Be Equal    ${payload}[topology]    mesh
    Dictionary Should Contain Key    ${payload}    members

Add Members To Mesh
    [Documentation]    POST federation to add a member to the mesh service.
    ${clusters}=    Get Clusters Config
    ${members}=    Evaluate
    ...    [{"type": "oscar", "cluster_id": "${CLUSTER_ID_B}", "service_name": "${WORKER2_SVC}", "priority": 1}]
    ${body}=    Create Dictionary    members=${members}    clusters=${clusters}
    ${data}=    Evaluate    json.dumps(${body})    json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/federation/${MESH_SVC}    data=${data}
    ...    headers=${HEADERS}    expected_status=ANY    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200

Get Federation Mesh With Members
    [Documentation]    GET federation on mesh and verify the member was added.
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/federation/${MESH_SVC}
    ...    headers=${HEADERS}    expected_status=200    verify=${SSL_VERIFY}
    Should Be Equal As Strings    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${members}=    Get From Dictionary    ${payload}    members
    Should Not Be Equal    ${members}    ${NONE}
    ${member_names}=    Evaluate    [m["service_name"] for m in $members]
    List Should Contain Value    ${member_names}    ${WORKER2_SVC}

Remove Mesh Federation Member
    [Documentation]    DELETE federation on mesh to remove member (delete=false).
    ${members}=    Evaluate
    ...    [{"type": "oscar", "cluster_id": "${CLUSTER_ID_B}", "service_name": "${WORKER2_SVC}"}]
    ${body}=    Create Dictionary    members=${members}    delete=${False}
    ${data}=    Evaluate    json.dumps(${body})    json
    ${headers}=    Create Dictionary    &{HEADERS}
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/federation/${MESH_SVC}
    ...    data=${data}    headers=${headers}    expected_status=ANY
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200

Get Federation Mesh After Removal
    [Documentation]    GET federation on mesh and verify the member was removed.
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/federation/${MESH_SVC}
    ...    headers=${HEADERS}    expected_status=200    verify=${SSL_VERIFY}
    Should Be Equal As Strings    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${members}=    Get From Dictionary    ${payload}    members
    ${member_names}=    Evaluate    [m["service_name"] for m in $members] if $members else []
    List Should Not Contain Value    ${member_names}    ${WORKER2_SVC}


*** Keywords ***
Initialize Federation Test Names
    [Documentation]    Generate unique service names for this suite run.
    ${suffix}=    Evaluate    ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))    modules=random,string
    Set Suite Variable    ${RANDOM_STRING}    ${suffix}
    Set Suite Variable    ${NON_FED_SVC}      robot-fed-non-${suffix}
    Set Suite Variable    ${WORKER1_SVC}      robot-fed-worker1-${suffix}
    Set Suite Variable    ${WORKER2_SVC}      robot-fed-worker2-${suffix}
    Set Suite Variable    ${MAIN_SVC}         robot-fed-main-${suffix}
    Set Suite Variable    ${MESH_SVC}         robot-fed-mesh-${suffix}
    Set Suite Variable    ${CLUSTER_ID_A}     oscar-jetson
    Set Suite Variable    ${CLUSTER_ID_B}     oscar-graspi
    Set Suite Variable    ${CLUSTER_ID_MAIN}  oscar-primary
    Set Suite Variable    ${NONE}             ${None}

Create Prerequisite Services
    [Documentation]    Create only 3 services to stay within MinIO bucket quota (limit 5).
    Create Simple Service    ${NON_FED_SVC}    ${CLUSTER_ID_MAIN}
    Create Simple Service    ${WORKER1_SVC}    ${CLUSTER_ID_A}
    Create Simple Service    ${WORKER2_SVC}    ${CLUSTER_ID_B}
    Wait Until Keyword Succeeds    ${SERVICE_TIMEOUT}    ${SERVICE_RETRY_INTERVAL}
    ...    Service Should Be Ready    ${NON_FED_SVC}
    Wait Until Keyword Succeeds    ${SERVICE_TIMEOUT}    ${SERVICE_RETRY_INTERVAL}
    ...    Service Should Be Ready    ${WORKER1_SVC}
    Wait Until Keyword Succeeds    ${SERVICE_TIMEOUT}    ${SERVICE_RETRY_INTERVAL}
    ...    Service Should Be Ready    ${WORKER2_SVC}

Create Simple Service
    [Documentation]    Create a basic service without federation config (no MinIO storage to avoid bucket quota).
    [Arguments]    ${name}    ${cluster_id}
    ${script}=    Catenate    SEPARATOR=\n
    ...    #!/bin/bash
    ...    sleep 10
    ${body}=    Create Dictionary
    ...    name=${name}
    ...    cluster_id=${cluster_id}
    ...    cpu=0.5
    ...    memory=256Mi
    ...    image=ubuntu
    ...    script=${script}
    ...    allowed_users=${EMPTY_LIST}
    ...    visibility=private
    ${data}=    Evaluate    json.dumps(${body})    json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    data=${data}
    ...    headers=${HEADERS}    expected_status=ANY    verify=${SSL_VERIFY}
    Log    Create ${name}: ${response.status_code} ${response.content}
    Should Be True    ${response.status_code} == 201 or ${response.status_code} == 409

Build Federation Service Body
    [Documentation]    Build a JSON service body with federation config and refresh_token.
    [Arguments]    ${name}    ${topology}
    ${secrets}=    Create Dictionary    refresh_token=dummy-token
    ${environment}=    Create Dictionary    secrets=${secrets}
    ${members}=    Create List
    ${federation}=    Create Dictionary
    ...    topology=${topology}
    ...    delegation=random
    ...    members=${members}
    ${script}=    Catenate    SEPARATOR=\n
    ...    #!/bin/bash
    ...    sleep 10
    ${body}=    Create Dictionary
    ...    name=${name}
    ...    cluster_id=${CLUSTER_ID_MAIN}
    ...    cpu=0.5
    ...    memory=256Mi
    ...    image=ubuntu
    ...    script=${script}
    ...    allowed_users=${EMPTY_LIST}
    ...    visibility=private
    ...    environment=${environment}
    ...    federation=${federation}
    ${json}=    Evaluate    json.dumps(${body})    json
    RETURN    ${json}

Get Clusters Config
    [Documentation]    Return the clusters map with all logical IDs pointing to the same endpoint.
    ${clusters}=    Create Dictionary
    ${entry}=    Create Dictionary    endpoint=${OSCAR_ENDPOINT}    ssl_verify=${SSL_VERIFY}
    Set To Dictionary    ${clusters}    ${CLUSTER_ID_MAIN}=${entry}
    Set To Dictionary    ${clusters}    ${CLUSTER_ID_A}=${entry}
    Set To Dictionary    ${clusters}    ${CLUSTER_ID_B}=${entry}
    RETURN    ${clusters}

Service Should Be Ready
    [Documentation]    Assert that the service status indicates readiness.
    [Arguments]    ${service_name}
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/${service_name}
    ...    headers=${HEADERS}    expected_status=200    verify=${SSL_VERIFY}
    Should Be Equal As Strings    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${status}=    Evaluate
    ...    (lambda d: d.get("status") if not isinstance(d.get("status"), dict) else d["status"].get("state") or d["status"].get("phase") or d["status"].get("condition"))(${payload})
    ...    json
    ${ready}=    Evaluate
    ...    str(${status}).lower() in ("ready","running","available","succeeded") or bool(${payload}.get("ready")) or bool(${payload}.get("token"))
    ...    json
    Should Be True    ${ready}    Service ${service_name} not ready yet (status=${status})

Cleanup Federation Test Artifacts
    [Documentation]    Remove all services created during federation tests.
    ${svcs}=    Create List
    ...    ${NON_FED_SVC}    ${MAIN_SVC}    ${MESH_SVC}
    ...    ${WORKER1_SVC}    ${WORKER2_SVC}
    FOR    ${svc}    IN    @{svcs}
        Run Keyword And Ignore Error    DELETE    url=${OSCAR_ENDPOINT}/system/services/${svc}
        ...    headers=${HEADERS}    expected_status=ANY    verify=${SSL_VERIFY}
    END
    Run Keyword And Ignore Error    Remove File    ${FED_STAR_FILE}
    Run Keyword And Ignore Error    Remove File    ${FED_MESH_FILE}
