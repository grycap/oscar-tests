*** Settings ***
Documentation       Verify user namespace network isolation through OSCAR APIs using the configured authentication flow.
Library             RequestsLibrary
Library             OperatingSystem
Library             yaml
Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/api_call.resource
Resource            ${CURDIR}/../../resources/service.resource

Suite Setup         Run Keywords    Checks Valids OIDC Token    AND    Verify Two Distinct Users    AND    Assign Random Network Policy Service Names
Suite Teardown      Cleanup Network Policy Services

*** Variables ***
${VICTIM_BASE}          robot-netpol-victim
${ATTACKER_BASE}        robot-netpol-attacker
${VICTIM_SERVICE_FILE}  ${DATA_DIR}/expose_services/nginx_expose.yaml
${NGINX_SCRIPT_FILE}    ${DATA_DIR}/expose_services/nginxscript.sh
${PROBE_SCRIPT_FILE}    ${CURDIR}/../../resources/network_policy_probe.py
${VICTIM_JSON}          ${DATA_DIR}/network_policy_victim.json
${ATTACKER_JSON}        ${DATA_DIR}/network_policy_attacker.json
${VICTIM_MARKER}        Welcome to nginx

*** Test Cases ***
Different User Cannot Reach Exposed Service Through Internal DNS
    [Documentation]    User B must not bypass the victim's Traefik authentication by calling its internal Service DNS.
    [Tags]    network-policy    oidc    exposed
    Create Victim Exposed Service
    Wait Until Keyword Succeeds    180s    5s    Victim Must Be Available Through Authenticated Traefik URL
    Create Attacker Probe Service
    Wait Until Keyword Succeeds    180s    5s    Attacker Probe Must Report Network Isolation

*** Keywords ***
Verify Two Distinct Users
    Should Not Be Equal    ${USER}    ${OTHER_USER}    The configured authentication resource must provide two distinct users.

Assign Random Network Policy Service Names
    ${victim}=    Generate Random Service Name    ${VICTIM_BASE}
    ${attacker}=    Generate Random Service Name    ${ATTACKER_BASE}
    Set Suite Variable    ${VICTIM_SERVICE}    ${victim}
    Set Suite Variable    ${ATTACKER_SERVICE}    ${attacker}

Create Victim Exposed Service
    ${content}=    Get File    ${VICTIM_SERVICE_FILE}
    ${content}=    Set Service File VO    ${content}
    ${service}=    Set Variable    ${content}[functions][oscar][0][oscar-cluster]
    Set To Dictionary    ${service}    name=${VICTIM_SERVICE}
    Set To Dictionary    ${service}    cpu=0.2    memory=128Mi
    ${script}=    Get File    ${NGINX_SCRIPT_FILE}
    ${content}=    Set Service File Script    ${content}    ${script}
    Dump Service File To JSON File    ${content}    ${VICTIM_JSON}
    ${body}=    Get File    ${VICTIM_JSON}
    ${response}=    POST With Defaults    ${OSCAR_ENDPOINT}/system/services    ${body}    ${HEADERS}
    Should Be Equal As Integers    ${response.status_code}    201    Victim service must be newly created: ${response.text}

Victim Must Be Available Through Authenticated Traefik URL
    ${url}=    Build Exposed Service URL    ${VICTIM_SERVICE}
    ${response}=    GET    url=${url}    expected_status=ANY    headers=&{HEADERS}    verify=${SSL_VERIFY}    timeout=15
    Should Be Equal As Integers    ${response.status_code}    200
    Should Contain    ${response.text}    ${VICTIM_MARKER}

Create Attacker Probe Service
    ${content}=    Get File    ${VICTIM_SERVICE_FILE}
    ${content}=    Set Service File VO    ${content}
    ${service}=    Set Variable    ${content}[functions][oscar][0][oscar-cluster]
    Set To Dictionary    ${service}    name=${ATTACKER_SERVICE}
    Set To Dictionary    ${service}    cpu=0.2    memory=128Mi
    Set To Dictionary    ${service}    image=python:3.12-alpine
    ${expose}=    Get From Dictionary    ${service}    expose
    Set To Dictionary    ${expose}    api_port=${{[8080]}}
    ${namespace}=    Get Victim Namespace
    ${target}=    Set Variable    http://${VICTIM_SERVICE}-svc.${namespace}.svc.cluster.local/
    ${variables}=    Create Dictionary    NETWORK_POLICY_TARGET_URL=${target}
    ${environment}=    Create Dictionary    variables=${variables}
    Set To Dictionary    ${service}    environment=${environment}
    ${probe}=    Get File    ${PROBE_SCRIPT_FILE}
    ${probe_b64}=    Evaluate    base64.b64encode($probe.encode()).decode()    modules=base64
    ${script}=    Get File    ${CURDIR}/../../resources/network_policy_probe.sh
    ${script}=    Replace String    ${script}    __PROBE_B64__    ${probe_b64}
    ${content}=    Set Service File Script    ${content}    ${script}
    Dump Service File To JSON File    ${content}    ${ATTACKER_JSON}
    ${body}=    Get File    ${ATTACKER_JSON}
    ${response}=    POST With Defaults    ${OSCAR_ENDPOINT}/system/services    ${body}    ${HEADERS2}
    Should Be Equal As Integers    ${response.status_code}    201    Attacker service must be newly created: ${response.text}

Get Victim Namespace
    ${response}=    GET With Defaults    ${OSCAR_ENDPOINT}/system/services/${VICTIM_SERVICE}    200    ${HEADERS}
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${namespace}=    Get From Dictionary    ${payload}    namespace
    Should Not Be Empty    ${namespace}
    RETURN    ${namespace}

Attacker Probe Must Report Network Isolation
    ${url}=    Build Exposed Service URL    ${ATTACKER_SERVICE}
    ${response}=    GET    url=${url}    expected_status=ANY    headers=&{HEADERS2}    verify=${SSL_VERIFY}    timeout=15
    Should Be Equal As Integers    ${response.status_code}    200
    Should Match Regexp    ${response.text}    ^BLOCKED:(timeout|connection_refused)$
    Should Not Contain    ${response.text}    ${VICTIM_MARKER}

Cleanup Network Policy Services
    Run Keyword And Ignore Error    DELETE With Defaults    ${OSCAR_ENDPOINT}/system/services/${ATTACKER_SERVICE}    204    ${HEADERS2}
    Run Keyword And Ignore Error    DELETE With Defaults    ${OSCAR_ENDPOINT}/system/services/${VICTIM_SERVICE}    204    ${HEADERS}
    Run Keyword And Ignore Error    Remove File    ${VICTIM_JSON}
    Run Keyword And Ignore Error    Remove File    ${ATTACKER_JSON}
