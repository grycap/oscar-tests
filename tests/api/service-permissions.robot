*** Settings ***
Documentation       Tests for the OSCAR Manager's API of a deployed OSCAR cluster. Different access control scenarios.

Resource            ${CURDIR}/../../resources/resources.resource
Resource            ${CURDIR}/../../resources/token.resource

Suite Setup         Check Valid OIDC Token
Suite Teardown      Clean Test Artifacts    True    ${DATA_DIR}/custom_service_file.json
...                     ${DATA_DIR}/custom_bucket.json


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

Update To Private Service
    [Documentation]    Update the created service
    Prepare Service File    PRIVATE
    ${body}=    Get File    ${DATA_DIR}/custom_service_file.json
    # ${body}=    Prepare Service File    PRIVATE
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Service Is Private
    [Documentation]    Check that the created service is private
    Check Service Visibility    PRIVATE

OSCAR Delete Service
    [Documentation]    Delete the created service
    [Tags]    delete
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Create Bucket
    [Documentation]    Create a new bucket
    [Tags]    create    bucket
    ${body}=    Get File    ${DATA_DIR}/bucket.json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=201    data=${body}
    ...    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

List Buckets
    [Documentation]    List all buckets
    [Tags]    bucket
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=200    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200

Bucket Is Public
    [Documentation]    Check that the created bucket is public
    [Tags]    bucket
    Check Bucket Visibility    public

Update To Restricted Bucket
    [Documentation]    Update the created bucket
    [Tags]    bucket
    Prepare Bucket File    restricted
    ${body}=    Get File    ${DATA_DIR}/custom_bucket.json
    # ${body}=    Prepare Bucket File    restricted
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/buckets    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Bucket Is Restricted
    [Documentation]    Check that the created bucket is restricted
    [Tags]    bucket
    Check Bucket Visibility    restricted

Update To Private Bucket
    [Documentation]    Update the created bucket
    [Tags]    bucket
    Prepare Bucket File    private
    ${body}=    Get File    ${DATA_DIR}/custom_bucket.json
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/buckets    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Bucket Is Private
    [Documentation]    Check that the created bucket is restricted
    [Tags]    bucket
    Check Bucket Visibility    private

Delete Bucket
    [Documentation]    Delete the created bucket
    [Tags]    delete    bucket
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/buckets/${BUCKET_NAME}    expected_status=204
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

Prepare Bucket File
    [Documentation]    Prepare the bucket file for bucket creation
    [Arguments]    ${expected_visibility}
    ${body_string}=    Get File    ${DATA_DIR}/bucket.json
    ${body}=    Convert String To JSON    ${body_string}

    ${body}=    Set Bucket File Visibility    ${body}    ${expected_visibility}    ${EGI_UID_1}

    ${json_output}=    Convert JSON To String    ${body}
    Create File    ${DATA_DIR}/custom_bucket.json    ${json_output}
    # RETURN    ${json_output}

Check Bucket Visibility
    [Documentation]    Check the visibility of a bucket
    [Arguments]    ${expected_visibility}
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=200    headers=${HEADERS}
    Log    ${response.content}

    # Parse JSON content to a list of dictionaries
    ${buckets}=    Convert String To Json    ${response.content}

    # Find the bucket dictionary with bucket_path == '${BUCKET_NAME}'
    ${robot_test_bucket}=    Evaluate    next((b for b in ${buckets} if b['bucket_path'] == '${BUCKET_NAME}'), None)

    # Check visibility
    Should Be Equal    ${robot_test_bucket['visibility']}    ${expected_visibility}
