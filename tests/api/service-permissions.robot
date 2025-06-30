*** Settings ***
Documentation       Tests for the OSCAR Manager's API of a deployed OSCAR cluster. Different service.

Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/token.resource

Suite Setup         Check Valid OIDC Token
Suite Teardown      Clean Test Artifacts    True    ${DATA_DIR}/custom_service_file.json


*** Test Cases ***
OSCAR Create Restricted Service
    [Documentation]    Create a new restricted service
    [Tags]    create
    Prepare Service File    RESTRICTED
    ${body}=    Get File    ${DATA_DIR}/custom_service_file.json
    # ${body}=    Prepare Service File    RESTRICTED

    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

Service Is Restricted
    [Documentation]    Check that the created service is restricted
    Check Service Visibility    RESTRICTED

Update Restricted To Private Service
    [Documentation]    Update the restricted service to private
    Prepare Service File    PRIVATE
    ${body}=    Get File    ${DATA_DIR}/custom_service_file.json
    # ${body}=    Prepare Service File    PRIVATE
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Invoke Asynchronous Private Service
    [Documentation]    Invoke the asynchronous private service
    ${body}=    Get File    ${INVOKE_FILE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/job/${SERVICE_NAME}    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR List Jobs
    [Documentation]    List all jobs from a service with their status
    ${list_jobs}=    GET    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}    expected_status=200
    ...    headers=${HEADERS}
    ${jobs_dict}=    Evaluate    dict(${list_jobs.content})
    Get Key From Dictionary    ${jobs_dict}
    Should Contain    ${JOB_NAME}    ${SERVICE_NAME}-

OSCAR Get Logs
    [Documentation]    Get the logs from a job
    FOR    ${_}    IN RANGE    ${MAX_RETRIES}
        ${result}=    Run Keyword And Ignore Error    GET
        ...    url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}/${JOB_NAME}    headers=${HEADERS}
        VAR    ${rc}=    ${result[0]}
        VAR    ${response_raw}=    ${result[1]}
        ${status_code}=    Set Variable If    '${rc}' == 'PASS'    ${response_raw.status_code}

        IF    '${status_code}' == '200'    BREAK

        Log    Service not ready yet. Status: ${response_raw}. Retrying in ${RETRY_INTERVAL}...
        Sleep    ${RETRY_INTERVAL}
    END
    Should Be Equal As Strings    ${status_code}    200    msg=Service was not ready after ${MAX_RETRIES} attempts

Service Is Private
    [Documentation]    Check that the created service is private
    Check Service Visibility    PRIVATE

OSCAR Delete Private Service
    [Documentation]    Delete the private service
    [Tags]    delete
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR Create Private Service
    [Documentation]    Create a new private service
    [Tags]    create
    Prepare Service File    PRIVATE
    ${body}=    Get File    ${DATA_DIR}/custom_service_file.json
    # ${body}=    Prepare Service File    PRIVATE

    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

Service Is Private
    [Documentation]    Check that the created service is private
    Check Service Visibility    PRIVATE

Update Private To Restricted Service
    [Documentation]    Update the restricted service to private
    Prepare Service File    RESTRICTED
    ${body}=    Get File    ${DATA_DIR}/custom_service_file.json
    # ${body}=    Prepare Service File    RESTRICTED
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Service Is Restricted
    [Documentation]    Check that the created service is restricted
    Check Service Visibility    RESTRICTED

OSCAR Delete Restricted Service
    [Documentation]    Delete the restricted service
    [Tags]    delete
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204




*** Keywords ***
Prepare Service File
    [Documentation]    Prepare the service file for service creation
    [Arguments]    ${expected_visibility}
    ${service_content}=    Load Original Service File    ${SERVICE_FILE}
    ${service_content}=    Set Service File VO    ${service_content}
    ${service_content}=    Set Service File Isolation Level    ${service_content}    ${expected_visibility}
    ...    ${EGI_UID_1}
    ${service_content}=    Set Service File Script    ${service_content}
    Dump Service File To JSON File    ${service_content}    ${DATA_DIR}/custom_service_file.json
    # RETURN    ${service_content}

Check Service Visibility
    [Documentation]    Check the visibility of the service
    [Arguments]    ${expected_visibility}

    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services    expected_status=200    headers=${HEADERS}
    Log    ${response.content}

    # Parse JSON content to a list of dictionaries
    ${services}=    Convert String To Json    ${response.content}

    # Find the service dictionary with name == '${SERVICE_NAME}'
    ${robot_test_service}=    Evaluate    next((a for a in ${services} if a['name'] == '${SERVICE_NAME}'), None)

    # Should Not Be None    ${robot_test_app}    App with name 'robot-test-cowsay' not found
    Should Be Equal    ${robot_test_service['isolation_level']}    ${expected_visibility}
