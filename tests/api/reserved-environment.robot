*** Settings ***
Documentation       Tests for the OSCAR Manager's API of a deployed OSCAR cluster. Basic endpoint coverage

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS} 
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/api_call.resource
Resource            ${CURDIR}/../../resources/service.resource



Suite Setup         Run Keywords    Check Valid OIDC Token    AND    Assign Random Service Name



Suite Teardown      Run Keywords    Cleanup Service Lifecycle Resources    AND    Clean Test Artifacts    ${DATA_DIR}/reserved_environment_service_file.json


*** Variables ***
${SERVICE_BASE}     robot-test-reserved-env-vars
${SERVICE_NAME}     ${SERVICE_BASE}


*** Test Cases ***
OSCAR Create Service with reserver env vars
    [Documentation]    Create a new service
    [Tags]    create    ready
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/reserved_environment_service_file.json    
    ${response}=    POST With Defaults  url=${OSCAR_ENDPOINT}/system/services   data=${body}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '500'


*** Keywords ***
Cleanup Service Lifecycle Resources
    [Documentation]    Best-effort cleanup of service and logs created by this suite.
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}?all=true    expected_status=ANY
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=ANY

Prepare Service File
    [Documentation]    Prepare the service file
    ${service_content}=    Get File    ${DATA_DIR}/simple-test.yaml
    ${service_content}=    Set Service File VO    ${service_content}

    # Extract the inner dictionary (remove 'functions', 'oscar' and 'oscar-cluster')
    VAR    ${modified_content}=    ${service_content}[functions][oscar][0][oscar-cluster]

    # Update the script value
    ${script_value}=    Set Variable    script
    Set To Dictionary    ${modified_content}    script=${script_value}
    Set To Dictionary    ${modified_content}    name=${SERVICE_NAME}
    ${input_entries}=    Get From Dictionary    ${modified_content}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${SERVICE_NAME}/input
    ${output_entries}=    Get From Dictionary    ${modified_content}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${SERVICE_NAME}/output
    ${environment_entries}=    Get From Dictionary    ${modified_content}    environment
    ${environment_variables}=    Get From Dictionary    ${environment_entries}    variables
    Set To Dictionary    ${environment_variables}    exec_timeout    0
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${DATA_DIR}/reserved_environment_service_file.json    ${service_content_json}
