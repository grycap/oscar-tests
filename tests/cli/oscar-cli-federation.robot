*** Settings ***
Documentation       Tests for the OSCAR CLI federation commands.
...                 Verifies CLI installation, service creation via CLI,
...                 and federation get on existing services.
...
...                 NOTE: oscar-cli v2.1.0 has known bugs in federation create/update
...                 (sends wrong payload format). These tests only cover the
...                 working subset of CLI federation commands.

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
    FOR    ${svc}    IN    ${NON_FED_SVC}    ${WORKER1_SVC}    ${WORKER2_SVC}    ${MAIN_SVC}
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
