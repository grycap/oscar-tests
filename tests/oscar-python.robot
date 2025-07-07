*** Settings ***
Documentation       Tests for the OSCAR Python library

Library             robot_libs.oscar_lib.OscarLibrary
Resource            ${CURDIR}/../resources/files.resource
Resource            ${CURDIR}/../resources/token.resource

Suite Setup         Check Valid OIDC Token
Suite Teardown      Clean Test Artifacts    True    ${DATA_DIR}/custom_service_file.yaml
...                     ${EXECDIR}/00-cowsay-invoke-body.json
Test Setup          Connect To Oscar Cluster


*** Variables ***
${SERVICE_FILE}     ${DATA_DIR}/00-cowsay.yaml
${SERVICE_NAME}     robot-test-cowsay
${CLUSTER_ID}       robot-oscar-cluster
${SSL}              True


*** Test Cases ***
Get Cluster Info
    [Documentation]    Retrieve information about the OSCAR cluster
    ${response}=    Get Cluster Info
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    200
    Should Contain    ${response.content}    "version":

Get Cluster Config
    [Documentation]    Retrieve the configuration of the OSCAR cluster
    ${response}=    Get Cluster Config
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    200
    Should Contain    ${response.content}    "config":

Create New Service
    [Documentation]    Create a new service with a given FDL file
    [Tags]    create
    Prepare Service File
    ${response}=    Create Service    ${DATA_DIR}/custom_service_file.yaml
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    201

Get Service Details
    [Documentation]    Retrieve details about a specific service
    ${response}=    Get Service    ${SERVICE_NAME}
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    200
    Should Contain    ${response.content}    "${SERVICE_NAME}"

List Services
    [Documentation]    List all services in the OSCAR cluster
    ${response}=    List Services
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    200
    Should Contain    ${response.content}    "name":

Run Service Synchronously
    [Documentation]    Wait until the service returns "ROBOT" in its response
    Wait Until Keyword Succeeds
    ...    ${MAX_RETRIES}x
    ...    ${RETRY_INTERVAL}
    ...    Service Should Return ROBOT    ${SERVICE_NAME}    ${INVOKE_FILE}

Update Existing Service
    [Documentation]    Update an existing service using a new FDL file
    ${response}=    Update Service    ${SERVICE_NAME}    ${DATA_DIR}/custom_service_file.yaml
    Log    ${response.content}
    Should Contain    [ '200', '204' ]    '${response.status_code}'

Run Service Asynchronously
    [Documentation]    Run a service asynchronously with input data
    ${response}=    Run Service Asynchronously    ${SERVICE_NAME}    ${INVOKE_FILE}
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    201

List Jobs
    [Documentation]    List all jobs created by the service
    ${response}=    List Jobs    ${SERVICE_NAME}
    Log    ${response.content}
    ${jobs_dict}=    Evaluate    dict(${response.content})
    Get Key From Dictionary    ${jobs_dict}
    Should Be Equal As Integers    ${response.status_code}    200

Get Job Logs
    [Documentation]    Check the logs of a job and wait until job logs contain "ROBOT"
    Wait Until Keyword Succeeds
    ...    ${MAX_RETRIES}x
    ...    ${RETRY_INTERVAL}
    ...    Job Logs Should Contain ROBOT    ${SERVICE_NAME}    ${JOB_NAME}

Remove Job
    [Documentation]    Remove a job created by the service
    ${response}=    Remove Job    ${SERVICE_NAME}    ${JOB_NAME}
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    204

Remove All Job
    [Documentation]    Remove all jobs created by the service
    ${response}=    Remove All Jobs    ${SERVICE_NAME}
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    204

Upload File
    [Documentation]    Upload a file to the service's storage provider
    Create Storage Object
    ${response}=    Upload File To Storage    minio.default
    ...    ${DATA_DIR}/00-cowsay-invoke-body.json    ${BUCKET_NAME}/input/robot-upload
    Log    ${response}

List Files From Path
    [Documentation]    List files from a specific path in the service's storage provider
    Create Storage Object
    ${response}=    List Files From Path    minio.default    ${BUCKET_NAME}/input/
    Log    ${response}

    FOR    ${item}    IN    @{response['Contents']}
        ${key}=    Get From Dictionary    ${item}    Key
        IF    '${key}' == 'input/robot-upload/00-cowsay-invoke-body.json'
            BREAK
        END
    END
    Should Be True    '${key}' == 'input/robot-upload/00-cowsay-invoke-body.json'

Download File
    [Documentation]    Download a file from the service's storage provider
    Create Storage Object
    ${response}=    Download File From Storage    minio.default
    ...    ${EXECDIR}    ${BUCKET_NAME}/input/robot-upload/00-cowsay-invoke-body.json
    Log    ${response}
    File Should Exist    ${EXECDIR}/00-cowsay-invoke-body.json

Remove Service
    [Documentation]    Remove a service by name
    [Tags]    delete
    ${response}=    Remove Service    ${SERVICE_NAME}
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    204


*** Keywords ***
Connect To Oscar Cluster
    [Documentation]    Connect to the OSCAR cluster using basic authentication
    ${token}=    Get Access Token
    Connect With Basic Auth    ${CLUSTER_ID}    ${OSCAR_ENDPOINT}    ${token}    ${SSL}

Prepare Service File
    [Documentation]    Prepare the service file for service creation
    ${service_content}=    Load Original Service File    ${SERVICE_FILE}
    ${service_content}=    Set Service File VO    ${service_content}
    Save YAML File    ${service_content}    ${DATA_DIR}/custom_service_file.yaml

Service Should Return ROBOT
    [Documentation]    Run a service synchronously with input data
    [Arguments]    ${service_name}    ${invoke_file}
    ${response}=    Run Service Synchronously    ${service_name}    ${invoke_file}
    Log    ${response.content}
    Should Contain    ${response.content}    ROBOT

Job Logs Should Contain ROBOT
    [Documentation]    Check if job logs contain "ROBOT"
    [Arguments]    ${service_name}    ${job_name}
    ${response}=    Get Job Logs    ${service_name}    ${job_name}
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    200
    Should Contain    ${response.content}    ROBOT

Create Storage Object
    [Documentation]    Create a storage object in the service's storage provider
    ${response}=    Create Storage Client    ${SERVICE_NAME}
    Log    ${response}
