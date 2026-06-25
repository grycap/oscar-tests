*** Settings ***
Documentation       Tests for the OSCAR CLI federation commands.
...                 Verifies CLI installation, service creation via CLI apply,
...                 and federation get/add-member/update/delete operations
...                 covering star and mesh topology workflows.

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/service.resource
Library             Collections
Library             Process
Library             String

Suite Setup         Setup Federation CLI Suite
Suite Teardown      Teardown Federation CLI Suite


*** Variables ***
@{EMPTY_LIST}=


*** Test Cases ***
OSCAR CLI Installed
    [Documentation]    Check that OSCAR CLI is installed.
    ${result}=    Run Process    oscar-cli    stdout=True    stderr=True
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Apply Services
    [Documentation]    Create the non-federated and worker services via CLI.
    Create Service Via CLI    ${NON_FED_SVC}    ${CLUSTER_ID_MAIN}
    Create Service Via CLI    ${WORKER1_SVC}    ${CLUSTER_ID_A}
    Create Service Via CLI    ${WORKER2_SVC}    ${CLUSTER_ID_B}

OSCAR CLI List Services
    [Documentation]    List services and check our created ones appear in table output.
    ${result}=    Run Process    oscar-cli    service    list
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${NON_FED_SVC}
    Should Contain    ${result.stdout}    ${WORKER1_SVC}
    Should Contain    ${result.stdout}    ${WORKER2_SVC}

OSCAR CLI Federation Get NonFederated
    [Documentation]    Get federation on a service without federation config.
    ...    The CLI returns exit code 1 with "not found" for services
    ...    that have no federation members (known CLI behavior).
    ${result}=    Run Process    oscar-cli    federation    get    ${NON_FED_SVC}
    ...    stdout=True    stderr=True
    Log    stdout: ${result.stdout}
    Log    stderr: ${result.stderr}
    # CLI returns 1 when the service has no federation members
    Should Be Equal As Integers    ${result.rc}    1

OSCAR CLI Apply Star Federation Service
    [Documentation]    Create the main service with star topology federation via CLI apply.
    Create Federation Service Via CLI    ${MAIN_SVC}    ${CLUSTER_ID_MAIN}    star

OSCAR CLI Federation Get Star Topology
    [Documentation]    Get federation on the star service and verify topology.
    ${result}=    Run Process    oscar-cli    federation    get    ${MAIN_SVC}    --output    json
    ...    stdout=True    stderr=True
    Log    stdout: ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    ${payload}=    Evaluate    json.loads($result.stdout)    json
    Should Be Equal    ${payload}[topology]    star
    Should Be Equal    ${payload}[members]    ${NONE}

OSCAR CLI Federation Add Members To Star
    [Documentation]    Add both worker services as federation members to the star service.
    ${result}=    Run Process    oscar-cli    federation    add-member    ${MAIN_SVC}
    ...    --cluster-id    ${CLUSTER_ID_A}    --service-name    ${WORKER1_SVC}    --priority    0
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    ${result}=    Run Process    oscar-cli    federation    add-member    ${MAIN_SVC}
    ...    --cluster-id    ${CLUSTER_ID_B}    --service-name    ${WORKER2_SVC}    --priority    1
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Federation Get Star With Members
    [Documentation]    Get federation after adding members and verify both workers appear.
    ${result}=    Run Process    oscar-cli    federation    get    ${MAIN_SVC}    --output    json
    ...    stdout=True    stderr=True
    Log    stdout: ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    ${payload}=    Evaluate    json.loads($result.stdout)    json
    Should Be Equal    ${payload}[topology]    star
    ${members}=    Get From Dictionary    ${payload}    members
    ${member_names}=    Evaluate    [m["service_name"] for m in $members]
    List Should Contain Value    ${member_names}    ${WORKER1_SVC}
    List Should Contain Value    ${member_names}    ${WORKER2_SVC}

OSCAR CLI Federation Update Priority
    [Documentation]    Update the priority of an existing member via CLI.
    ${result}=    Run Process    oscar-cli    federation    update    ${MAIN_SVC}
    ...    --cluster-id    ${CLUSTER_ID_A}    --service-name    ${WORKER1_SVC}    --priority    10
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Federation Get Star After Update
    [Documentation]    Get federation and verify the priority was updated.
    ${result}=    Run Process    oscar-cli    federation    get    ${MAIN_SVC}    --output    json
    ...    stdout=True    stderr=True
    Log    stdout: ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    ${payload}=    Evaluate    json.loads($result.stdout)    json
    ${members}=    Get From Dictionary    ${payload}    members
    ${priorities}=    Evaluate    {m["service_name"]: m["priority"] for m in $members}
    Should Be Equal As Integers    ${priorities}[${WORKER1_SVC}]    10
    Should Be Equal As Integers    ${priorities}[${WORKER2_SVC}]    1

OSCAR CLI Federation Remove Members From Star
    [Documentation]    Remove all federation members from the star service.
    ${result}=    Run Process    oscar-cli    federation    delete    ${MAIN_SVC}
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Federation Get Star After Removal
    [Documentation]    Get federation and verify no members remain.
    ${result}=    Run Process    oscar-cli    federation    get    ${MAIN_SVC}    --output    json
    ...    stdout=True    stderr=True
    Log    stdout: ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    ${payload}=    Evaluate    json.loads($result.stdout)    json
    Should Be Equal    ${payload}[topology]    star
    Should Be Equal    ${payload}[members]    ${NONE}

OSCAR CLI Delete Star Service
    [Documentation]    Delete the main star service to free MinIO buckets for the mesh test.
    ${result}=    Run Process    oscar-cli    service    delete    ${MAIN_SVC}
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Run Keyword And Ignore Error    Remove File    ${DATA_DIR}/${MAIN_SVC}.yaml
    Run Keyword And Ignore Error    Remove File    ${DATA_DIR}/${MAIN_SVC}.sh

OSCAR CLI Apply Mesh Federation Service
    [Documentation]    Create a service with mesh topology federation via CLI apply.
    Create Federation Service Via CLI    ${MESH_SVC}    ${CLUSTER_ID_MAIN}    mesh

OSCAR CLI Federation Get Mesh Topology
    [Documentation]    Get federation on the mesh service and verify topology.
    ${result}=    Run Process    oscar-cli    federation    get    ${MESH_SVC}    --output    json
    ...    stdout=True    stderr=True
    Log    stdout: ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    ${payload}=    Evaluate    json.loads($result.stdout)    json
    Should Be Equal    ${payload}[topology]    mesh
    Should Be Equal    ${payload}[members]    ${NONE}

OSCAR CLI Federation Add Member To Mesh
    [Documentation]    Add a worker service as federation member to the mesh service.
    ${result}=    Run Process    oscar-cli    federation    add-member    ${MESH_SVC}
    ...    --cluster-id    ${CLUSTER_ID_B}    --service-name    ${WORKER2_SVC}    --priority    1
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Federation Get Mesh With Member
    [Documentation]    Get federation on mesh and verify the member was added.
    ${result}=    Run Process    oscar-cli    federation    get    ${MESH_SVC}    --output    json
    ...    stdout=True    stderr=True
    Log    stdout: ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    ${payload}=    Evaluate    json.loads($result.stdout)    json
    ${members}=    Get From Dictionary    ${payload}    members
    ${member_names}=    Evaluate    [m["service_name"] for m in $members]
    List Should Contain Value    ${member_names}    ${WORKER2_SVC}

OSCAR CLI Federation Remove Members From Mesh
    [Documentation]    Remove all federation members from the mesh service.
    ${result}=    Run Process    oscar-cli    federation    delete    ${MESH_SVC}
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Federation Get Mesh After Removal
    [Documentation]    Get federation on mesh and verify no members remain.
    ${result}=    Run Process    oscar-cli    federation    get    ${MESH_SVC}    --output    json
    ...    stdout=True    stderr=True
    Log    stdout: ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    ${payload}=    Evaluate    json.loads($result.stdout)    json
    Should Be Equal    ${payload}[topology]    mesh
    Should Be Equal    ${payload}[members]    ${NONE}


*** Keywords ***
Setup Federation CLI Suite
    [Documentation]    Set up OIDC token, add cluster, and generate service names.
    ${exists}=    Run Keyword And Return Status    Variable Should Exist    ${REFRESH_TOKEN}
    IF  not ${exists}
        Set Refresh Token
    END
    ${suffix}=    Evaluate    ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))    modules=random,string
    Set Suite Variable    ${NON_FED_SVC}      robot-cli-fed-non-${suffix}
    Set Suite Variable    ${WORKER1_SVC}      robot-cli-fed-w1-${suffix}
    Set Suite Variable    ${WORKER2_SVC}      robot-cli-fed-w2-${suffix}
    Set Suite Variable    ${MAIN_SVC}         robot-cli-fed-main-${suffix}
    Set Suite Variable    ${MESH_SVC}         robot-cli-fed-mesh-${suffix}
    Set Suite Variable    ${CLUSTER_ID_A}     oscar-jetson
    Set Suite Variable    ${CLUSTER_ID_B}     oscar-graspi
    Set Suite Variable    ${CLUSTER_ID_MAIN}  oscar-primary
    Set Suite Variable    ${NONE}             ${None}
    FOR    ${alias}    IN    robot-oscar-cluster    ${CLUSTER_ID_MAIN}    ${CLUSTER_ID_A}    ${CLUSTER_ID_B}
        ${result}=    Run Process    oscar-cli    cluster    add    ${alias}    ${OSCAR_ENDPOINT}
        ...    --oidc-refresh-token    ${REFRESH_TOKEN}    stdout=True    stderr=True
        Log    ${result.stdout}
    END
    ${result}=    Run Process    oscar-cli    cluster    default    --set    robot-oscar-cluster
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Contain    ${result.stdout}    successfully

Teardown Federation CLI Suite
    [Documentation]    Clean up all services and configuration files.
    FOR    ${svc}    IN    ${NON_FED_SVC}    ${WORKER1_SVC}    ${WORKER2_SVC}    ${MAIN_SVC}    ${MESH_SVC}
        Run Keyword And Ignore Error    Run Process    oscar-cli    service    delete    ${svc}
        ...    stdout=True    stderr=True
        Run Keyword And Ignore Error    Remove File    ${DATA_DIR}/${svc}.yaml
        Run Keyword And Ignore Error    Remove File    ${DATA_DIR}/${svc}.sh
    END
    FOR    ${alias}    IN    robot-oscar-cluster    ${CLUSTER_ID_MAIN}    ${CLUSTER_ID_A}    ${CLUSTER_ID_B}
        Run Keyword And Ignore Error    Run Process    oscar-cli    cluster    remove    ${alias}
        ...    stdout=True    stderr=True
    END

Create Service Via CLI
    [Documentation]    Write a YAML file and a script file, then apply via CLI.
    [Arguments]    ${name}    ${cluster_id}
    Create File    ${DATA_DIR}/${name}.sh    \#\!/bin/bash\nsleep 10\n
    ${yaml_text}=    Evaluate    yaml.dump({"functions": {"oscar": [{"${cluster_id}": {"name": "${name}", "cpu": "0.5", "memory": "256Mi", "image": "ubuntu", "script": "${name}.sh", "allowed_users": [], "visibility": "private"}}]}}, default_flow_style=False)
    Create File    ${DATA_DIR}/${name}.yaml    ${yaml_text}
    ${result}=    Run Process    oscar-cli    apply    ${DATA_DIR}/${name}.yaml
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

Create Federation Service Via CLI
    [Documentation]    Write a YAML file with federation config and apply via CLI.
    [Arguments]    ${name}    ${cluster_id}    ${topology}
    Create File    ${DATA_DIR}/${name}.sh    \#\!/bin/bash\nsleep 10\n
    ${yaml_text}=    Evaluate
    ...    yaml.dump({"functions": {"oscar": [{"${cluster_id}": {"name": "${name}", "cpu": "0.5", "memory": "256Mi", "image": "ubuntu", "script": "${name}.sh", "allowed_users": [], "visibility": "private", "environment": {"secrets": {"refresh_token": "dummy-token"}}, "federation": {"topology": "${topology}", "delegation": "random", "members": []}}}]}}, default_flow_style=False)
    Create File    ${DATA_DIR}/${name}.yaml    ${yaml_text}
    ${result}=    Run Process    oscar-cli    apply    ${DATA_DIR}/${name}.yaml
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
