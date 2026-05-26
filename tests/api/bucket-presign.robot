*** Settings ***
Documentation       Tests for the OSCAR API /system/buckets/{name}/presign endpoint.

Library             Collections
Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/api_call.resource

Suite Setup         Run Keywords    Check Valid OIDC Token    AND    Initialize Presign Test Names
Suite Teardown      Cleanup Presign Test Artifacts


*** Variables ***
${BUCKET_CONFIG_FILE}   ${DATA_DIR}/bucket.json


*** Test Cases ***
OSCAR Create Bucket For Presign
    [Documentation]    Create a bucket to test presigned URL generation.
    ${body}=    Get File    ${BUCKET_CONFIG_FILE}
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/buckets    data=${body}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201

OSCAR Presign Bucket Download
    [Documentation]    Generate a presigned URL for downloading from a bucket.
    ${body}=    Create Presign Payload    test-file.txt    download
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/${bucket_name}/presign    data=${body}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    Dictionary Should Contain Key    ${payload}    url
    Should Not Be Empty    ${payload}[url]
    Should Contain    ${payload}[url]    ${bucket_name}

OSCAR Presign Bucket Upload
    [Documentation]    Generate a presigned URL for uploading to a bucket.
    ${body}=    Create Presign Payload    upload-file.txt    upload
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/${bucket_name}/presign    data=${body}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '201'

OSCAR Presign Bucket With Expires
    [Documentation]    Generate a presigned URL with custom expiration time.
    ${body}=    Create Presign Payload    test-file.txt    download    3600
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/${bucket_name}/presign    data=${body}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    ${payload}=    Evaluate    json.loads($response.content)    json
    Dictionary Should Contain Key    ${payload}    url
    Should Not Be Empty    ${payload}[url]

OSCAR Presign Bucket Not Found
    [Documentation]    Generate a presigned URL for a non-existent bucket.
    ${body}=    Create Presign Payload    test-file.txt    download
    ${response}=    POST With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/nonexistent-bucket/presign    data=${body}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '403' or '${response.status_code}' == '404'


*** Keywords ***
Initialize Presign Test Names
    [Documentation]    Use the default bucket name from the bucket config file.
    ${content}=    Get File    ${BUCKET_CONFIG_FILE}
    ${bucket_name}=    Evaluate    json.loads($content).get("bucket_name", "robot-test")    json
    Set Suite Variable    ${bucket_name}    ${bucket_name}

Create Presign Payload
    [Documentation]    Build a JSON payload for the presign endpoint.
    [Arguments]    ${object_key}    ${operation}=download    ${expires}=0
    ${payload}=    Create Dictionary    object_key=${object_key}    operation=${operation}
    IF    ${expires} > 0
        Set To Dictionary    ${payload}    expires=${expires}
    END
    ${body}=    Evaluate    json.dumps(${payload})    json
    RETURN    ${body}

Cleanup Presign Test Artifacts
    [Documentation]    Remove the bucket created for presign testing.
    Run Keyword And Ignore Error    DELETE With Defaults    url=${OSCAR_ENDPOINT}/system/buckets/${bucket_name}
