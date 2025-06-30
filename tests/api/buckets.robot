*** Settings ***
Documentation       Tests for the OSCAR Manager's API of a deployed OSCAR cluster. Different bucket permissions.

Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/token.resource

Suite Setup         Check Valid OIDC Token
Suite Teardown      Clean Test Artifacts    True    ${DATA_DIR}/custom_bucket.json


*** Test Cases ***
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
