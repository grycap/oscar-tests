*** Settings ***
Documentation       Tests for the OSCAR Manager's API of a deployed OSCAR cluster. Different bucket permissions.

Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/token.resource

Suite Setup         Check Valid OIDC Token
Suite Teardown      Clean Test Artifacts    True    ${DATA_DIR}/custom_bucket.json


*** Test Cases ***
Create Public Bucket
    [Documentation]    Create a new public bucket
    [Tags]    create    bucket
    Create Bucket    public

List Buckets
    [Documentation]    List all buckets
    [Tags]    bucket
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=200    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200

Update Public To Restricted Bucket
    [Documentation]    Update the public bucket to restricted
    Update Bucket    restricted    ${EGI_UID_1}    ${EGI_UID_2}

Update Restricted To Private Bucket
    [Documentation]    Update the restricted bucket to private
    Update Bucket    private

Delete Private Bucket
    [Documentation]    Delete the private bucket
    [Tags]    delete    bucket
    Check Bucket Visibility    private
    Delete Bucket

Create Private Bucket
    [Documentation]    Create a new private bucket
    [Tags]    create    bucket
    Create Bucket    private

Update Private To Restricted Bucket
    [Documentation]    Update the private bucket to restricted
    Update Bucket    restricted    ${EGI_UID_1}

Delete Restricted Bucket
    [Documentation]    Delete the restricted bucket
    [Tags]    delete    bucket
    Check Bucket Visibility    restricted    ${EGI_UID_1}
    Delete Bucket

Create Restricted Bucket
    [Documentation]    Create a new restricted bucket
    [Tags]    create    bucket
    Create Bucket    restricted    ${EGI_UID_1}

Update Restricted To Public Bucket
    [Documentation]    Update the restricted bucket to public
    Update Bucket    public

Update Public To Private Bucket
    [Documentation]    Update the public bucket to private
    Update Bucket    private

Update Private To Public Bucket
    [Documentation]    Update the private bucket to public
    Update Bucket    public

Delete Public Bucket
    [Documentation]    Delete the public bucket
    [Tags]    delete    bucket
    Check Bucket Visibility    public
    Delete Bucket


*** Keywords ***
Create Bucket
    [Documentation]    Create a new bucket with the given visibility and optional EGI UID
    [Arguments]    ${visibility}    @{egi_uid}
    Prepare Bucket File    ${visibility}    @{egi_uid}
    ${body}=    Get File    ${DATA_DIR}/custom_bucket.json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=201
    ...    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201
    Check Bucket Visibility    ${visibility}    @{egi_uid}

Update Bucket
    [Documentation]    Update an existing bucket with the given visibility and optional EGI UID
    [Arguments]    ${visibility}    @{egi_uid}
    Prepare Bucket File    ${visibility}    @{egi_uid}
    ${body}=    Get File    ${DATA_DIR}/custom_bucket.json
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/buckets    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Contain    [ '200', '204' ]    '${response.status_code}'
    Check Bucket Visibility    ${visibility}    @{egi_uid}

Delete Bucket
    [Documentation]    Delete the current bucket
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/buckets/${BUCKET_NAME}
    ...    expected_status=204    headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Prepare Bucket File
    [Documentation]    Prepare the bucket file for bucket creation
    [Arguments]    ${expected_visibility}    @{allowed_users}
    ${body_string}=    Get File    ${DATA_DIR}/bucket.json
    ${body}=    Convert String To JSON    ${body_string}
    ${body}=    Set Bucket File Visibility    ${body}    ${expected_visibility}
    ${body}=    Set Bucket File Allowed Users    ${body}    @{allowed_users}

    ${json_output}=    Convert JSON To String    ${body}
    Create File    ${DATA_DIR}/custom_bucket.json    ${json_output}
    # RETURN    ${json_output}

Check Bucket Visibility
    [Documentation]    Check the visibility of a bucket
    [Arguments]    ${expected_visibility}    @{expected_allowed_users}
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=200    headers=${HEADERS}
    Log    ${response.content}

    # Parse JSON content to a list of dictionaries
    ${buckets}=    Convert String To Json    ${response.content}

    # Find the bucket dictionary with bucket_path == '${BUCKET_NAME}'
    ${robot_test_bucket}=    Evaluate    next((b for b in ${buckets} if b['bucket_path'] == '${BUCKET_NAME}'), None)

    # Check visibility
    Should Be Equal    ${robot_test_bucket['visibility']}    ${expected_visibility}

    # Validate allowed_users
    ${actual_allowed_users}=    Get From Dictionary    ${robot_test_bucket}    allowed_users
    Validate Allowed Users    ${actual_allowed_users}    @{expected_allowed_users}

Validate Allowed Users
    [Documentation]    Validate that actual allowed_users matches expected allowed_users
    [Arguments]    ${actual_allowed_users}    @{expected_allowed_users}
    ${expected_count}=    Get Length    ${expected_allowed_users}
    
    # No users in allowed_users
    IF    ${expected_count} == 0
        Should Be Equal    ${actual_allowed_users}    ${None}
    ELSE
        # Check that actual_allowed_users is a list (there are 2 UIDs or more)
        ${is_list}=    Evaluate    isinstance(${actual_allowed_users}, list)
        Should Be True    ${is_list}
        ${actual_count}=    Get Length    ${actual_allowed_users}
        Should Be Equal As Integers    ${actual_count}    ${expected_count}
        
        # For each expected UID, check it matches in the actual list
        FOR    ${uid}    IN    @{expected_allowed_users}
            Should Contain    ${actual_allowed_users}    ${uid}
        END

    END
