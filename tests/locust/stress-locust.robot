*** Settings ***
Documentation       Stress tests for the OSCAR Manager API executed through Locust.

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS} 
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/service.resource
Library             OperatingSystem
Library             Process

Suite Setup         Setup Stress Environment
Suite Teardown      Teardown Stress Environment


*** Variables ***
${LOCUSTFILE}                   ${CURDIR}/oscar_api.py
${STRESS_SERVICE_BASE}          robot-test-cowsay
${STRESS_SERVICE_NAME}          ${STRESS_SERVICE_BASE}
${LOCUST_WAIT_MIN}              1
${LOCUST_WAIT_MAX}              2
${SMOKE_USERS}                  2
${SMOKE_SPAWN_RATE}             1
${SMOKE_RUN_TIME}               5s
${SUSTAINED_USERS}              20
${SUSTAINED_SPAWN_RATE}         5
${SUSTAINED_RUN_TIME}           1m
${LOCUST_OUTPUT_DIR}            ${EXECDIR}/robot_results/locust
${LOCUST_OUTPUT_PREFIX}         ${LOCUST_OUTPUT_DIR}/latest


*** Test Cases ***
OSCAR API Stress Smoke
    [Documentation]    Run a short Locust session to validate the stress harness.
    [Tags]    stress    smoke
    Run Locust Load Test    ${SMOKE_USERS}    ${SMOKE_SPAWN_RATE}    ${SMOKE_RUN_TIME}

OSCAR API Stress Sustained
    [Documentation]    Run a longer Locust session to observe sustained behaviour.
    [Tags]    stress    long
    Run Locust Load Test    ${SUSTAINED_USERS}    ${SUSTAINED_SPAWN_RATE}    ${SUSTAINED_RUN_TIME}


*** Keywords ***
Setup Stress Environment
    [Documentation]    Prepare tokens and environment variables for Locust.
    ${service_name}=    Generate Random Service Name    ${STRESS_SERVICE_BASE}
    Set Suite Variable    ${STRESS_SERVICE_NAME}    ${service_name}
    Create Directory    ${LOCUST_OUTPUT_DIR}
    ${output_prefix}=    Catenate    SEPARATOR=/    ${LOCUST_OUTPUT_DIR}    ${service_name}
    Set Suite Variable    ${LOCUST_OUTPUT_PREFIX}    ${output_prefix}
    ${access_token}=    Get Access Token
    Check JWT Expiration    ${access_token}
    Set Suite Variable    ${ACCESS_TOKEN}    ${access_token}
    Set Environment Variable    OSCAR_ACCESS_TOKEN    ${access_token}
    Set Environment Variable    OSCAR_SERVICE_NAME    ${STRESS_SERVICE_NAME}
    Set Environment Variable    LOCUST_WAIT_MIN    ${LOCUST_WAIT_MIN}
    Set Environment Variable    LOCUST_WAIT_MAX    ${LOCUST_WAIT_MAX}
    Ensure Stress Service Exists

Teardown Stress Environment
    [Documentation]    Clean environment variables created for Locust.
    Run Keyword And Ignore Error    Delete Stress Service
    Run Keyword And Ignore Error    Remove Environment Variable    OSCAR_ACCESS_TOKEN
    Run Keyword And Ignore Error    Remove Environment Variable    OSCAR_SERVICE_NAME
    Run Keyword And Ignore Error    Remove Environment Variable    LOCUST_WAIT_MIN
    Run Keyword And Ignore Error    Remove Environment Variable    LOCUST_WAIT_MAX

Run Locust Load Test
    [Documentation]    Execute Locust headlessly with the provided parameters.
    [Arguments]    ${users}    ${spawn_rate}    ${run_time}
    ${command}=    Create List    locust    -f    ${LOCUSTFILE}    --headless    -u    ${users}
    ...    -r    ${spawn_rate}    -t    ${run_time}    --host=${OSCAR_ENDPOINT}    --stop-timeout=30
    ...    --csv=${LOCUST_OUTPUT_PREFIX}    --csv-full-history    --html=${LOCUST_OUTPUT_PREFIX}.html
    ${result}=    Run Process    @{command}    stdout=True    stderr=True    cwd=${CURDIR}
    Log    ${result.stdout}
    Log    ${result.stderr}
    Should Be Equal As Integers    ${result.rc}    0
    Log    Locust CSV written to ${LOCUST_OUTPUT_PREFIX}_stats.csv and HTML report at ${LOCUST_OUTPUT_PREFIX}.html

Ensure Stress Service Exists
    [Documentation]    Create the stress service if it is not already present.
    ${service_url}=    Catenate    SEPARATOR=    ${OSCAR_ENDPOINT}/system/services/    ${STRESS_SERVICE_NAME}
    ${response}=    GET With Defaults    ${service_url}    expected_status=ANY
    Run Keyword If    '${response.status_code}'=='200'    RETURN
    Prepare Stress Service File
    ${body}=    Get File    ${DATA_DIR}/stress_service.json
    ${create_response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    Should Be True    '${create_response.status_code}' == '201' or '${create_response.status_code}' == '409'
    Run Keyword If    '${create_response.status_code}'=='201'    Sleep    30s

Prepare Stress Service File
    [Documentation]    Generate the service definition file for the stress service.
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Set Service File VO    ${service_content}
    VAR    ${modified_content}=    ${service_content}[functions][oscar][0][robot-oscar-cluster]
    Set To Dictionary    ${modified_content}    name=${STRESS_SERVICE_NAME}
    ${input_entries}=    Get From Dictionary    ${modified_content}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${STRESS_SERVICE_NAME}/input
    ${output_entries}=    Get From Dictionary    ${modified_content}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${STRESS_SERVICE_NAME}/output
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    modules=json
    Create File    ${DATA_DIR}/stress_service.json    ${service_content_json}

Delete Stress Service
    [Documentation]    Remove the stress service created for the tests.
    ${delete_url}=    Catenate    SEPARATOR=    ${OSCAR_ENDPOINT}/system/services/    ${STRESS_SERVICE_NAME}
    ${response}=    DELETE With Defaults    ${delete_url}    expected_status=ANY
    Log    ${response.status_code}
    Run Keyword And Ignore Error    Remove File    ${DATA_DIR}/stress_service.json

GET With Defaults
    [Arguments]    ${url}    ${expected_status}=200    ${headers}=${HEADERS}
    ${headers}=    Run Keyword If    '${LOCAL_TESTING}'=='True'    Set Variable    ${HEADERS_OSCAR}    ELSE    Set Variable    ${headers}
    ${response}=    GET    url=${url}    expected_status=${expected_status}    verify=${SSL_VERIFY}    headers=&{headers}
    RETURN    ${response}

POST With Defaults
    [Arguments]    ${url}    ${data}    ${headers}=${HEADERS}
    ${headers}=    Run Keyword If    '${LOCAL_TESTING}'=='True'    Set Variable    ${HEADERS_OSCAR}    ELSE    Set Variable    ${headers}
    ${response}=    POST    url=${url}    data=${data}    expected_status=ANY    verify=${SSL_VERIFY}    headers=&{headers}
    RETURN    ${response}

DELETE With Defaults
    [Arguments]    ${url}    ${expected_status}=204    ${headers}=${HEADERS}
    ${headers}=    Run Keyword If    '${LOCAL_TESTING}'=='True'    Set Variable    ${HEADERS_OSCAR}    ELSE    Set Variable    ${headers}
    ${response}=    DELETE    url=${url}    expected_status=${expected_status}    verify=${SSL_VERIFY}    headers=&{headers}
    RETURN    ${response}
