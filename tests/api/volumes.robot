*** Settings ***
Documentation       Tests for OSCAR managed volumes through /system/volumes.

Library             RequestsLibrary
Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/files.resource

Suite Setup         Run Keywords    Configure Authentication    AND    Initialize Volume Test Names
Suite Teardown      Cleanup Volume Test Resources


*** Variables ***
${VOLUME_SIZE}              1Gi
${VOLUME_MOUNT_PATH}        /data
${VOLUME_SERVICE_FILE}      ${DATA_DIR}/volume_service_file.json


*** Test Cases ***
OSCAR Volumes API Health
    [Documentation]    Check API health before testing managed volumes.
    ${response}=    GET    url=${OSCAR_ENDPOINT}/health    expected_status=200    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

OSCAR Create API Volume
    [Documentation]    Create a managed volume directly through /system/volumes.
    [Tags]    create    volumes
    ${body}=    Build Volume Payload    ${CRUD_VOLUME_NAME}    ${VOLUME_SIZE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/volumes    expected_status=ANY    data=${body}
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201
    Volume Response Should Match    ${response}    ${CRUD_VOLUME_NAME}    api

OSCAR Read API Volume
    [Documentation]    Read the managed volume created through the API.
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/volumes/${CRUD_VOLUME_NAME}    expected_status=200
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Volume Response Should Match    ${response}    ${CRUD_VOLUME_NAME}    api

OSCAR List API Volumes
    [Documentation]    List managed volumes and verify the API-created volume is present.
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/volumes    expected_status=200
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Volume List Should Contain    ${response}    ${CRUD_VOLUME_NAME}

OSCAR Reject Duplicate API Volume
    [Documentation]    Creating a managed volume with the same name in the same namespace must fail.
    ${body}=    Build Volume Payload    ${CRUD_VOLUME_NAME}    ${VOLUME_SIZE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/volumes    expected_status=ANY    data=${body}
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    409

OSCAR Reject Invalid API Volume
    [Documentation]    Invalid managed volume names must be rejected.
    ${body}=    Build Volume Payload    Invalid_Name    ${VOLUME_SIZE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/volumes    expected_status=ANY    data=${body}
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    400

OSCAR Delete API Volume
    [Documentation]    Delete a detached managed volume created through the API.
    [Tags]    delete    volumes
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/volumes/${CRUD_VOLUME_NAME}    expected_status=204
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR Verify API Volume Deleted
    [Documentation]    The deleted managed volume must no longer be readable.
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/volumes/${CRUD_VOLUME_NAME}    expected_status=404
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Should Be Equal As Strings    ${response.status_code}    404

OSCAR Create Volume For Existing Mount
    [Documentation]    Create a reusable managed volume before attaching it to a service.
    [Tags]    create    volumes
    ${body}=    Build Volume Payload    ${ATTACH_VOLUME_NAME}    ${VOLUME_SIZE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/volumes    expected_status=ANY    data=${body}
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201
    Volume Response Should Match    ${response}    ${ATTACH_VOLUME_NAME}    api

OSCAR Create Service Mounting Existing Volume
    [Documentation]    Create a service that mounts an existing managed volume.
    [Tags]    create    volumes
    ${volume}=    Create Dictionary    name=${ATTACH_VOLUME_NAME}    mount_path=${VOLUME_MOUNT_PATH}
    Prepare Volume Service File    ${ATTACH_SERVICE_NAME}    ${volume}
    ${body}=    Get File    ${VOLUME_SERVICE_FILE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=ANY    data=${body}
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201
    Wait Until Keyword Succeeds    180s    5s    Service Should Report Volume    ${ATTACH_SERVICE_NAME}    ${ATTACH_VOLUME_NAME}    ${HEADERS}

OSCAR Read Attached Volume Metadata
    [Documentation]    A mounted volume must report its service attachment.
    Wait Until Keyword Succeeds    120s    5s    Volume Should Have Attachment    ${ATTACH_VOLUME_NAME}    ${ATTACH_SERVICE_NAME}

OSCAR Reject Delete Attached Volume
    [Documentation]    Deleting a volume attached to a service must fail.
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/volumes/${ATTACH_VOLUME_NAME}    expected_status=ANY
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    400

OSCAR Delete Service Mounting Existing Volume
    [Documentation]    Delete the service before deleting the attached API-created volume.
    [Tags]    delete    volumes
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${ATTACH_SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204
    Wait Until Keyword Succeeds    120s    5s    Volume Should Be Detached    ${ATTACH_VOLUME_NAME}

OSCAR Delete Detached Existing Volume
    [Documentation]    Delete the reusable volume once no service is attached.
    [Tags]    delete    volumes
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/volumes/${ATTACH_VOLUME_NAME}    expected_status=204
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR Create Service With Retained Volume
    [Documentation]    Create a service-owned volume with lifecycle_policy retain.
    [Tags]    create    volumes
    ${volume}=    Create Dictionary    size=${VOLUME_SIZE}    mount_path=${VOLUME_MOUNT_PATH}    lifecycle_policy=retain
    Prepare Volume Service File    ${RETAIN_SERVICE_NAME}    ${volume}
    ${body}=    Get File    ${VOLUME_SERVICE_FILE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=ANY    data=${body}
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201
    Wait Until Keyword Succeeds    180s    5s    Service Should Report Volume    ${RETAIN_SERVICE_NAME}    ${RETAIN_VOLUME_NAME}    ${HEADERS}
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/volumes/${RETAIN_VOLUME_NAME}    expected_status=200
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Volume Response Should Match    ${response}    ${RETAIN_VOLUME_NAME}    service    retain

OSCAR Delete Retain Service Keeps Volume
    [Documentation]    A retained service-owned volume must survive service deletion.
    [Tags]    delete    volumes
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${RETAIN_SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204
    Wait Until Keyword Succeeds    120s    5s    Volume Should Be Detached    ${RETAIN_VOLUME_NAME}
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/volumes/${RETAIN_VOLUME_NAME}    expected_status=200
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Volume Response Should Match    ${response}    ${RETAIN_VOLUME_NAME}    service    retain

OSCAR Delete Retained Volume
    [Documentation]    Clean up the retained managed volume explicitly.
    [Tags]    delete    volumes
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/volumes/${RETAIN_VOLUME_NAME}    expected_status=204
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

OSCAR Create Service With Delete Policy Volume
    [Documentation]    Create a service-owned volume with lifecycle_policy delete.
    [Tags]    create    volumes
    ${volume}=    Create Dictionary    name=${DELETE_VOLUME_NAME}    size=${VOLUME_SIZE}    mount_path=${VOLUME_MOUNT_PATH}    lifecycle_policy=delete
    Prepare Volume Service File    ${DELETE_SERVICE_NAME}    ${volume}
    ${body}=    Get File    ${VOLUME_SERVICE_FILE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=ANY    data=${body}
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201
    Wait Until Keyword Succeeds    180s    5s    Service Should Report Volume    ${DELETE_SERVICE_NAME}    ${DELETE_VOLUME_NAME}    ${HEADERS}
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/volumes/${DELETE_VOLUME_NAME}    expected_status=200
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Volume Response Should Match    ${response}    ${DELETE_VOLUME_NAME}    service    delete

OSCAR Delete Service Removes Delete Policy Volume
    [Documentation]    A delete-policy service-owned volume must be removed with its service.
    [Tags]    delete    volumes
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${DELETE_SERVICE_NAME}    expected_status=204
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204
    Wait Until Keyword Succeeds    120s    5s    Volume Should Not Exist    ${DELETE_VOLUME_NAME}

OSCAR Volumes Namespace Isolation
    [Documentation]    A volume created by one OIDC user must not be visible or reusable by another user.
    [Tags]    volumes    isolation
    Auxiliary Headers Should Be Available
    ${body}=    Build Volume Payload    ${ISOLATION_VOLUME_NAME}    ${VOLUME_SIZE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/volumes    expected_status=ANY    data=${body}
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    201
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/volumes    expected_status=ANY
    ...    headers=${HEADERS2}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    200
    ...    msg=Auxiliary user could not list managed volumes: ${response.content}
    Volume List Should Not Contain    ${response}    ${ISOLATION_VOLUME_NAME}
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/volumes/${ISOLATION_VOLUME_NAME}    expected_status=404
    ...    headers=${HEADERS2}    verify=${SSL_VERIFY}
    Should Be Equal As Strings    ${response.status_code}    404
    ${volume}=    Create Dictionary    name=${ISOLATION_VOLUME_NAME}    mount_path=${VOLUME_MOUNT_PATH}
    Prepare Volume Service File    ${ISOLATION_SERVICE_NAME}    ${volume}
    ${body}=    Get File    ${VOLUME_SERVICE_FILE}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    expected_status=ANY    data=${body}
    ...    headers=${HEADERS2}    verify=${SSL_VERIFY}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    400
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/volumes/${ISOLATION_VOLUME_NAME}    expected_status=204
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Should Be Equal As Strings    ${response.status_code}    204


*** Keywords ***
Configure Authentication
    [Documentation]    Use two OIDC users when the auth resource provides them; otherwise fall back to the default auth setup.
    ${has_multi_user_auth}=    Run Keyword And Return Status    Keyword Should Exist    Checks Valids OIDC Token
    IF    ${has_multi_user_auth}
        Checks Valids OIDC Token
    ELSE
        Check Valid OIDC Token
    END

Initialize Volume Test Names
    [Documentation]    Generate DNS-compatible resource names for this suite run.
    ${suffix}=    Evaluate    ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))    modules=random,string
    Set Suite Variable    ${CRUD_VOLUME_NAME}         robot-api-${suffix}
    Set Suite Variable    ${ATTACH_VOLUME_NAME}       robot-attach-${suffix}
    Set Suite Variable    ${ATTACH_SERVICE_NAME}      robot-attach-svc-${suffix}
    Set Suite Variable    ${RETAIN_SERVICE_NAME}      robot-retain-svc-${suffix}
    Set Suite Variable    ${RETAIN_VOLUME_NAME}       robot-retain-svc-${suffix}
    Set Suite Variable    ${DELETE_SERVICE_NAME}      robot-delete-svc-${suffix}
    Set Suite Variable    ${DELETE_VOLUME_NAME}       robot-delete-${suffix}
    Set Suite Variable    ${ISOLATION_SERVICE_NAME}   robot-isolation-svc-${suffix}
    Set Suite Variable    ${ISOLATION_VOLUME_NAME}    robot-isolation-${suffix}

Build Volume Payload
    [Documentation]    Build a /system/volumes create payload.
    [Arguments]    ${name}    ${size}
    ${payload}=    Create Dictionary    name=${name}    size=${size}
    ${body}=    Evaluate    json.dumps(${payload})    json
    RETURN    ${body}

Prepare Volume Service File
    [Documentation]    Prepare a service payload with a managed volume block.
    [Arguments]    ${service_name}    ${volume}
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Set Service File VO    ${service_content}
    VAR    ${modified_content}=    ${service_content}[functions][oscar][0][robot-oscar-cluster]
    ${script_value}=    Catenate
    ...    \#!/bin/sh\n\nif [ \"$INPUT_TYPE\" = \"json\" ]\nthen\n
    ...    jq '.message' \"$INPUT_FILE_PATH\" -r | /usr/games/cowsay\nelse\n
    ...    cat \"$INPUT_FILE_PATH\" | /usr/games/cowsay\nfi\n\
    Set To Dictionary    ${modified_content}    script=${script_value}
    Set To Dictionary    ${modified_content}    name=${service_name}
    Set To Dictionary    ${modified_content}    volume=${volume}
    ${input_entries}=    Get From Dictionary    ${modified_content}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${service_name}/input
    ${output_entries}=    Get From Dictionary    ${modified_content}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${service_name}/output
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${VOLUME_SERVICE_FILE}    ${service_content_json}

Volume Response Should Match
    [Documentation]    Validate common managed-volume response fields.
    [Arguments]    ${response}    ${name}    ${creation_mode}=${EMPTY}    ${lifecycle_policy}=${EMPTY}
    ${payload}=    Evaluate    json.loads($response.content)    json
    Should Be Equal As Strings    ${payload["name"]}    ${name}
    Should Be Equal As Strings    ${payload["size"]}    ${VOLUME_SIZE}
    Dictionary Should Contain Key    ${payload}    status
    Run Keyword If    '${creation_mode}' != ''    Should Be Equal As Strings    ${payload["creation_mode"]}    ${creation_mode}
    Run Keyword If    '${lifecycle_policy}' != ''    Should Be Equal As Strings    ${payload["lifecycle_policy"]}    ${lifecycle_policy}

Volume List Should Contain
    [Documentation]    Assert that a volume name is present in a list response.
    [Arguments]    ${response}    ${volume_name}
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${names}=    Evaluate    [item.get("name") for item in $payload]
    Should Contain    ${names}    ${volume_name}

Volume List Should Not Contain
    [Documentation]    Assert that a volume name is absent from a list response.
    [Arguments]    ${response}    ${volume_name}
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${names}=    Evaluate    [item.get("name") for item in $payload]
    Should Not Contain    ${names}    ${volume_name}

Service Should Report Volume
    [Documentation]    Read a service until its volume status is visible.
    [Arguments]    ${service_name}    ${volume_name}    ${headers}
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services/${service_name}    expected_status=200
    ...    headers=${headers}    verify=${SSL_VERIFY}
    ${payload}=    Evaluate    json.loads($response.content)    json
    Dictionary Should Contain Key    ${payload}    volume_status
    Should Be True    ${payload["volume_status"]["enabled"]}
    Should Be Equal As Strings    ${payload["volume_status"]["name"]}    ${volume_name}

Volume Should Have Attachment
    [Documentation]    Read a managed volume until the expected service attachment appears.
    [Arguments]    ${volume_name}    ${service_name}
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/volumes/${volume_name}    expected_status=200
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    ${payload}=    Evaluate    json.loads($response.content)    json
    Should Be Equal As Strings    ${payload["status"]["phase"]}    in_use
    Should Be Equal As Integers    ${payload["status"]["attachment_count"]}    1
    ${attachments}=    Get From Dictionary    ${payload}    attachments
    ${first_attachment}=    Get From List    ${attachments}    0
    Should Be Equal As Strings    ${first_attachment["service_name"]}    ${service_name}
    Should Be Equal As Strings    ${first_attachment["mount_path"]}    ${VOLUME_MOUNT_PATH}

Volume Should Be Detached
    [Documentation]    Read a managed volume until it has no service attachments.
    [Arguments]    ${volume_name}
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/volumes/${volume_name}    expected_status=200
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    ${payload}=    Evaluate    json.loads($response.content)    json
    ${attachment_count}=    Evaluate    $payload.get("status", {}).get("attachment_count", 0)
    Should Be Equal As Integers    ${attachment_count}    0

Volume Should Not Exist
    [Documentation]    Assert that a managed volume cannot be read.
    [Arguments]    ${volume_name}
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/volumes/${volume_name}    expected_status=404
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Should Be Equal As Strings    ${response.status_code}    404

Auxiliary Headers Should Be Available
    [Documentation]    Skip tests that require a second authenticated user when it is not configured.
    ${has_headers2}=    Run Keyword And Return Status    Variable Should Exist    \${HEADERS2}
    Skip If    not ${has_headers2}    Auxiliary authentication headers are not available.

Cleanup Volume Test Resources
    [Documentation]    Best-effort cleanup of services, volumes and generated payloads.
    Run Keyword And Ignore Error    DELETE    url=${OSCAR_ENDPOINT}/system/services/${ATTACH_SERVICE_NAME}    expected_status=ANY
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Run Keyword And Ignore Error    DELETE    url=${OSCAR_ENDPOINT}/system/services/${RETAIN_SERVICE_NAME}    expected_status=ANY
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Run Keyword And Ignore Error    DELETE    url=${OSCAR_ENDPOINT}/system/services/${DELETE_SERVICE_NAME}    expected_status=ANY
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Cleanup Auxiliary Service
    Run Keyword And Ignore Error    DELETE    url=${OSCAR_ENDPOINT}/system/volumes/${CRUD_VOLUME_NAME}    expected_status=ANY
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Run Keyword And Ignore Error    DELETE    url=${OSCAR_ENDPOINT}/system/volumes/${ATTACH_VOLUME_NAME}    expected_status=ANY
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Run Keyword And Ignore Error    DELETE    url=${OSCAR_ENDPOINT}/system/volumes/${RETAIN_VOLUME_NAME}    expected_status=ANY
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Run Keyword And Ignore Error    DELETE    url=${OSCAR_ENDPOINT}/system/volumes/${DELETE_VOLUME_NAME}    expected_status=ANY
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Run Keyword And Ignore Error    DELETE    url=${OSCAR_ENDPOINT}/system/volumes/${ISOLATION_VOLUME_NAME}    expected_status=ANY
    ...    headers=${HEADERS}    verify=${SSL_VERIFY}
    Run Keyword And Ignore Error    Remove File    ${VOLUME_SERVICE_FILE}

Cleanup Auxiliary Service
    [Documentation]    Remove any service that may have been attempted with the auxiliary user.
    ${has_headers2}=    Run Keyword And Return Status    Variable Should Exist    \${HEADERS2}
    IF    ${has_headers2}
        Run Keyword And Ignore Error    DELETE    url=${OSCAR_ENDPOINT}/system/services/${ISOLATION_SERVICE_NAME}    expected_status=ANY
        ...    headers=${HEADERS2}    verify=${SSL_VERIFY}
    END
