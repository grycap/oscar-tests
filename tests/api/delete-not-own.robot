*** Settings ***
Documentation     Tests for the OSCAR Manager's API to verify that a user cannot delete a resource that does not belong to them.

Library           RequestsLibrary
Resource          ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource          ${CURDIR}/../../resources/files.resource
Resource          ${CURDIR}/../../resources/api_call.resource
Resource          ${CURDIR}/../../resources/service.resource

Suite Setup       Checks Valids OIDC Token
Suite Teardown    Run Keywords    Cleanup Delete Not Own Resources    AND    Clean Test Artifacts    ${DATA_DIR}/service_file.json


*** Variables ***
${BUCKET_NAME}    robot-test-not-own


*** Test Cases ***
OSCAR API Health
    [Documentation]    Check API health
    ${response}=    GET With Defaults   ${OSCAR_ENDPOINT}/health
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

OSCAR Create Bucket For Delete Not Own Test
    [Documentation]    Create a bucket owned by the current user
    ${body}=    Get File    ${DATA_DIR}/bucket.json
    ${body}=  yaml.Safe Load  ${body}
    ${body}=    Set To Dictionary    ${body}    bucket_name=${BUCKET_NAME}
    ${body}=    Set Bucket File Visibility      ${body}     restricted
    ${body}=    Set Bucket File Allowed Users   ${body}     ${USER}
    ${body}=    Convert JSON To String 	${body}
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/buckets    data=${body}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

Verify Bucket Creation By Current User
    [Documentation]    Verify the bucket exists and belongs to the current user
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${BUCKET_NAME}"

OSCAR Delete Bucket As Non-Owner Should Fail
    [Documentation]    Attempt to delete a bucket that belongs to another user and verify it is forbidden
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/buckets/${BUCKET_NAME}    expected_status=403    headers=${HEADERS2}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Contain    ${response.content}    is not authorised
    Should Be Equal As Strings    ${response.status_code}    403

Verify Bucket Still Exists After Failed Deletion
    [Documentation]    Confirm the bucket still exists after the non-owner delete attempt
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${BUCKET_NAME}"


*** Keywords ***
Cleanup Delete Not Own Resources
    [Documentation]    Best-effort cleanup of the bucket created by this suite.
    Run Keyword And Ignore Error    DELETE    url=${OSCAR_ENDPOINT}/system/buckets/${BUCKET_NAME}    expected_status=ANY    headers=${HEADERS}    verify=${SSL_VERIFY}

Verify Bucket
    [Documentation]    List all buckets
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=200    verify=${SSL_VERIFY}    headers=${HEADERS}
    RETURN       ${response}
