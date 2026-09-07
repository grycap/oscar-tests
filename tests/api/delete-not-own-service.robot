*** Settings ***
Documentation     Tests for the OSCAR Manager's API to verify that a user cannot delete a service that does not belong to them.

Library           RequestsLibrary
Resource          ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource          ${CURDIR}/../../resources/files.resource
Resource          ${CURDIR}/../../resources/api_call.resource
Resource          ${CURDIR}/../../resources/service.resource

Suite Setup       Run Keywords    Checks Valids OIDC Token    AND    Assign Random Service Name
Suite Teardown    Run Keywords    Cleanup Delete Not Own Service Resources    AND    Clean Test Artifacts    ${DATA_DIR}/service_file.json


*** Variables ***
${SERVICE_BASE}    robot-test-not-own


*** Test Cases ***
OSCAR API Health
    [Documentation]    Check API health
    ${response}=    GET With Defaults   ${OSCAR_ENDPOINT}/health
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

OSCAR Create Service For Delete Not Own Test
    [Documentation]    Create a service owned by the current user with restricted visibility
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${USER}
    Append To List      ${users}    ${OTHER_USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${body}=    Update File     ${body}      visibility     restricted
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

Verify Service Creation By Current User
    [Documentation]    Verify the service exists and belongs to the current user
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "name":"${SERVICE_NAME}"

OSCAR Delete Service As Non-Owner Should Fail
    [Documentation]    Attempt to delete a service that belongs to another user and verify it is forbidden
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=403    headers=${HEADERS2}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Contain    ${response.content}    You do not have permission to delete this service
    Should Be Equal As Strings    ${response.status_code}    403

Verify Service Still Exists After Failed Deletion
    [Documentation]    Confirm the service still exists after the non-owner delete attempt
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "name":"${SERVICE_NAME}"

OSCAR Create Private Service For Delete Not Own Test
    [Documentation]    Create a private service owned by the current user
    Prepare Service File With Name    ${SERVICE_BASE}-private
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${USER}
    ${body}=    Update File     ${body}      visibility     private
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201
    Set Suite Variable    ${SERVICE_PRIVATE_NAME}    ${SERVICE_BASE}-private

Verify Private Service Creation By Current User
    [Documentation]    Verify the private service exists and belongs to the current user
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_PRIVATE_NAME}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "name":"${SERVICE_PRIVATE_NAME}"

OSCAR Delete Private Service As Non-Owner Should Fail
    [Documentation]    Attempt to delete a private service as another user and verify it is forbidden
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_PRIVATE_NAME}    expected_status=403    headers=${HEADERS2}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Contain    ${response.content}    You do not have permission to delete this service
    Should Be Equal As Strings    ${response.status_code}    403

OSCAR Delete Non-Existent Service Should Fail
    [Documentation]    Attempt to delete a service that does not exist and verify it returns not found
    ${non_existent_name}=    Evaluate    'robot-test-non-existent-' + ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))    modules=random,string
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${non_existent_name}    expected_status=ANY    headers=${HEADERS2}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Not Be Equal As Strings    ${response.status_code}    204
    Should Contain    ${response.content}    You do not have permission to delete this service
    Should Be Equal As Strings    ${response.status_code}    403

Verify Private Service Still Exists After Failed Deletion
    [Documentation]    Confirm the private service still exists after the non-owner delete attempt
    ${response}=    GET With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_PRIVATE_NAME}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "name":"${SERVICE_PRIVATE_NAME}"


*** Keywords ***
Prepare Service File
    [Documentation]    Prepare the service file
    ${service_content}=    Modify Service File

    # Extract the inner dictionary (remove 'functions', 'oscar' and 'robot-oscar-cluster')
    ${modified_content}=    Set Variable    ${service_content}[functions][oscar][0][robot-oscar-cluster]

    # Update the script value
    ${script_value}=    Catenate
    ...    \#!/bin/sh\n\nif [ \"$INPUT_TYPE\" = \"json\" ]\nthen\n
    ...    jq '.message' \"$INPUT_FILE_PATH\" -r | /usr/games/cowsay\nelse\n
    ...    cat \"$INPUT_FILE_PATH\" | /usr/games/cowsay\nfi\n\
    Set To Dictionary    ${modified_content}    script=${script_value}
    Set To Dictionary    ${modified_content}    name=${SERVICE_NAME}
    ${input_entries}=    Get From Dictionary    ${modified_content}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${SERVICE_NAME}/input
    ${output_entries}=    Get From Dictionary    ${modified_content}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${SERVICE_NAME}/output
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${DATA_DIR}/service_file.json    ${service_content_json}

Prepare Service File With Name
    [Documentation]    Prepare the service file with a specific name
    [Arguments]    ${service_name}
    ${service_content}=    Modify Service File

    # Extract the inner dictionary (remove 'functions', 'oscar' and 'robot-oscar-cluster')
    ${modified_content}=    Set Variable    ${service_content}[functions][oscar][0][robot-oscar-cluster]

    # Update the script value
    ${script_value}=    Catenate
    ...    \#!/bin/sh\n\nif [ \"$INPUT_TYPE\" = \"json\" ]\nthen\n
    ...    jq '.message' \"$INPUT_FILE_PATH\" -r | /usr/games/cowsay\nelse\n
    ...    cat \"$INPUT_FILE_PATH\" | /usr/games/cowsay\nfi\n\
    Set To Dictionary    ${modified_content}    script=${script_value}
    Set To Dictionary    ${modified_content}    name=${service_name}
    ${input_entries}=    Get From Dictionary    ${modified_content}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${service_name}/input
    ${output_entries}=    Get From Dictionary    ${modified_content}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${service_name}/output
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${DATA_DIR}/service_file.json    ${service_content_json}

Modify Service File
    [Documentation]    Modify the service file with the VO
    ${yaml_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${loaded_content}=    yaml.Safe Load    ${yaml_content}
    Set To Dictionary    ${loaded_content}[functions][oscar][0][robot-oscar-cluster]    vo=${VO}
    RETURN    ${loaded_content}

Update File
    [Arguments]    ${content}       ${key}      ${value}
    ${loaded_content}=    yaml.Safe Load    ${content}
    Set To Dictionary    ${loaded_content}    ${key}=${value}
    ${service_content_json}=    Evaluate    json.dumps(${loaded_content})    json
    RETURN      ${service_content_json}

Cleanup Delete Not Own Service Resources
    [Documentation]    Best-effort cleanup of the services created by this suite.
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=ANY
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_PRIVATE_NAME}    expected_status=ANY
