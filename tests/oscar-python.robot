*** Settings ***
Documentation       Tests for the OSCAR Python library

Library             robot_libs.oscar_lib.OscarLibrary
Resource            ${CURDIR}/../${AUTHENTICATION_PROCESS} 
Resource            ${CURDIR}/../resources/files.resource

Test Setup          Connect To Oscar Cluster
Suite Teardown      Clean Test Artifacts    True    ${DATA_DIR}/service_file.yaml
...                     ${EXECDIR}/00-cowsay-invoke-body.json


*** Variables ***
${CLUSTER_ID}       robot-oscar-cluster
${SSL}              True
${SERVICE_NAME}     robot-test-cowsay
${bucket_name}      robot-test-cowsay

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
    Prepare Service File
    ${response}=    Create Service    ${DATA_DIR}/service_file.yaml
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    201

List Services
    [Documentation]    List all services in the OSCAR cluster
    ${response}=    List Services
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    200
    Should Contain    ${response.content}    "name":

Get Service Details
    [Documentation]    Retrieve details about a specific service
    ${response}=    Get Service    ${SERVICE_NAME}
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    200
    Should Contain    ${response.content}    "${SERVICE_NAME}"

Run Service Asynchronously
    [Documentation]    Run a service asynchronously with input data
    ${response}=    Run Service Asynchronously    ${SERVICE_NAME}    ${INVOKE_FILE}
    Sleep    120s
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    201

List Jobs
    [Documentation]    List all jobs created by the service
    ${response}=    List Jobs    ${SERVICE_NAME}
    Log    ${response.content}
    ${jobs_dict}=    Evaluate    dict(${response.content})
    Get Key From Dictionary    ${jobs_dict["jobs"]} 
    Should Be Equal As Integers    ${response.status_code}    200

Get Job Logs
    [Documentation]    Check the logs of a job
    FOR    ${i}    IN RANGE    ${MAX_RETRIES}
        ${status}    ${resp}=    Run Keyword And Ignore Error    Get Job Logs    ${SERVICE_NAME}    ${JOB_NAME}
        IF    '${status}' != 'FAIL'
            ${status}=    Run Keyword And Return Status    Should Contain    ${resp.content}    Hello
            Exit For Loop If    ${status}
        END
        Sleep   ${RETRY_INTERVAL}
    END
    Log    Exited

Remove Job
    [Documentation]    Remove a job created by the service
    ${response}=    Remove Job    ${SERVICE_NAME}    ${JOB_NAME}
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    204

Update Existing Service
    [Documentation]    Update an existing service using a new FDL file
    ${response}=    Update Service    ${SERVICE_NAME}    ${DATA_DIR}/service_file.yaml
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Remove All Job
    [Documentation]    Remove all jobs created by the service
    ${response}=    Remove All Jobs    ${SERVICE_NAME}
    Log    ${response.content}
    Should Be Equal As Integers    ${response.status_code}    204

Upload File
    [Documentation]    Upload a file to the service's storage provider
    Create Storage Object
    ${response}=    Upload File To Storage    minio.default
    ...    ${DATA_DIR}/00-cowsay-invoke-body.json    ${bucket_name}/input/robot-upload
    Log    ${response}

List Files From Path
    [Documentation]    List files from a specific path in the service's storage provider
    Create Storage Object
    ${response}=    List Files From Path    minio.default    ${bucket_name}/input/
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
    ...    ${EXECDIR}    ${bucket_name}/input/robot-upload/00-cowsay-invoke-body.json
    Log    ${response}
    File Should Exist    ${EXECDIR}/00-cowsay-invoke-body.json

Run Service Synchronously
    [Documentation]    Run a service synchronously with input data
    FOR    ${i}    IN RANGE    ${MAX_RETRIES}
    ${status}    ${resp}=    Run Keyword And Ignore Error    Run Service Synchronously    ${SERVICE_NAME}    ${INVOKE_FILE}
        IF    '${status}' != 'FAIL'
            Log     ${status}
            Log     ${resp.content}
            ${contain_robot}=    Run Keyword And Return Status    Should Contain    ${resp.text}    ROBOT
            Log     ${contain_robot}
            IF    ${contain_robot}
                Pass Execution    Execution contains 'ROBOT'
            END
        END
        Sleep   ${RETRY_INTERVAL}
    END
    Fail

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
    [Documentation]    Prepare the service file
    ${service_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${service_content}=    Set Service File VO    ${service_content}
    # Convert file content to YAML
    ${output}=    yaml.Dump    ${service_content}
    Create File    ${DATA_DIR}/service_file.yaml    ${output}

Create Storage Object
    [Documentation]    Create a storage object in the service's storage provider
    ${response}=    Create Storage Client    ${SERVICE_NAME}
    Log    ${response}
