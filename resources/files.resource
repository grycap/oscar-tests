*** Settings ***
Documentation       Common file operations and shared variables

Library             Collections
Library             OperatingSystem
Library             yaml


*** Variables ***
${SERVICE_NAME}         robot-test-cowsay
${OSCAR_ENDPOINT}       ${OSCAR_ENDPOINT}
${VO}                   ${EGI_VO}
${DATA_DIR}             ${EXECDIR}/data
${INVOKE_FILE}          ${DATA_DIR}/00-cowsay-invoke-body.json
${SCRIPT_FILE}          ${DATA_DIR}/00-cowsay-script.sh
${SERVICE_FILE}         ${DATA_DIR}/00-cowsay.yaml
${EGI_UID_1}            ${EGI_UID}


*** Keywords ***
Clean Test Artifacts
    [Documentation]    Removes junk files generared in the tests
    [Arguments]    @{files}
    FOR    ${file}    IN    @{files}
        Remove File    ${file}
        File Should Not Exist    ${file}
    END

Get Key From Dictionary
    [Documentation]    Get the key from a dictionary
    [Arguments]    ${dict}
    ${keys}=    Get Dictionary Keys    ${dict}
    IF    not ${keys}    Fail    The dictionary is empty. Cannot extract job.
    VAR    ${JOB_NAME}=    ${keys}[0]    scope=SUITE
    RETURN    ${JOB_NAME}

Load Original Service File
    [Documentation]    Load the original service file and return its content
    [Arguments]    ${filename}
    ${yaml_content}=    Get File    ${filename}
    ${loaded_content}=    yaml.Safe Load    ${yaml_content}
    RETURN    ${loaded_content}

Set Service File VO
    [Documentation]    Set the VO for the OSCAR service in the service file
    [Arguments]    ${service_content}
    Set To Dictionary    ${service_content}[functions][oscar][0][robot-oscar-cluster]    vo=${VO}
    RETURN    ${service_content}

Add Secret Echo To Script File
    [Documentation]    Append echo of the secret created
    ${script_content}=    Get File    ${SCRIPT_FILE}
    ${new_script}=    Catenate    SEPARATOR=\n    ${script_content}    echo "Secret key is: \$SECRET_KEY"
    RETURN    ${new_script}

Set Service File Script
    [Documentation]    Set the service script for the OSCAR service in the service file
    [Arguments]    ${service_content}    ${script_content}=None

    ${oscar_list}=    Get From Dictionary    ${service_content}[functions]    oscar
    ${modified_content}=    Get From Dictionary    ${oscar_list}[0]    robot-oscar-cluster

    IF    $script_content == None
        ${script}=    Get File    ${SCRIPT_FILE}
    ELSE
        VAR    ${script}=    ${script_content}
    END

    Set To Dictionary    ${modified_content}    script=${script}
    RETURN    ${service_content}

Set Service File Secret
    [Documentation]    Add secret to the OSCAR service in the service file
    [Arguments]    ${service_content}    ${secret_key}
    IF    '${secret_key}' == 'None' or '${secret_key}' == ''
        RETURN    ${service_content}
    END
    ${secrets}=    Create Dictionary    SECRET_KEY    ${secret_key}
    ${environment}=    Create Dictionary    secrets    ${secrets}
    Set To Dictionary    ${service_content}[functions][oscar][0][robot-oscar-cluster]    environment    ${environment}
    RETURN    ${service_content}

Set Service File Isolation Level
    [Documentation]    Set the isolation level for the OSCAR service in the service file
    [Arguments]    ${service_content}    ${isolation_level}
    Set To Dictionary    ${service_content}[functions][oscar][0][robot-oscar-cluster]
    ...    isolation_level=${isolation_level}
    RETURN    ${service_content}

Set Service File Allowed Users
    [Documentation]    Set the allowed users for the OSCAR service in the service file
    [Arguments]    ${service_content}    @{allowed_users}
    Set To Dictionary    ${service_content}[functions][oscar][0][robot-oscar-cluster]
    ...    allowed_users=@{allowed_users}
    RETURN    ${service_content}

Set Bucket File Visibility
    [Documentation]    Modify the visibility of a bucket in the bucket file
    [Arguments]    ${bucket_json}    ${visibility}
    Set To Dictionary    ${bucket_json}    visibility=${visibility}
    RETURN    ${bucket_json}

Set Bucket File Allowed Users
    [Documentation]    Modify the allowed users of a bucket in the bucket file
    [Arguments]    ${bucket_json}    @{allowed_users}
    Set To Dictionary    ${bucket_json}    allowed_users=${allowed_users}
    RETURN    ${bucket_json}

Dump Service File To JSON File
    [Documentation]    Dump the service content to a JSON file
    [Arguments]    ${service_content}    ${saved_file}
    ${oscar_list}=    Get From Dictionary    ${service_content}[functions]    oscar
    ${cluster_dict}=    Get From Dictionary    ${oscar_list}[0]    robot-oscar-cluster
    ${json_string}=    Evaluate    json.dumps(${cluster_dict})    json
    Create File    ${saved_file}    ${json_string}

Save YAML File
    [Documentation]    Save the service content to a YAML file
    [Arguments]    ${service_content}    ${saved_file}
    ${yaml_string}=    yaml.Safe Dump    ${service_content}
    Create File    ${saved_file}    ${yaml_string}
