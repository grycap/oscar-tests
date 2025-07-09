*** Settings ***
Documentation       Common file operations and shared variables

Library             Collections
Library             OperatingSystem
Library             yaml


*** Variables ***
${OSCAR_ENDPOINT}       ${OSCAR_ENDPOINT}
${VO}                   ${EGI_VO}
${DATA_DIR}             ${EXECDIR}/data
${INVOKE_FILE}          ${DATA_DIR}/00-cowsay-invoke-body.json
${EGI_UID_1}            ${EGI_UID}

${BUCKET_NAME}          robot-test
${MAX_RETRIES}          20
${RETRY_INTERVAL}       5s


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
    [Documentation]    Set or add the VO for the OSCAR service in the service file
    [Arguments]    ${service_content}

    # Get the first element inside functions -> oscar
    ${first_service_item}=    Get From List    ${service_content}[functions][oscar]    0

    # Get its key (e.g., 'robot-oscar-cluster' or 'oscar-cluster')
    ${service_name}=    Get Dictionary Keys    ${first_service_item}
    ${service_name}=    Get From List    ${service_name}    0

    # Add or update 'vo' field
    Set To Dictionary    ${first_service_item}[${service_name}]    vo=${VO}

    RETURN    ${service_content}

Add Secret Echo To Script File
    [Documentation]    Append echo of the secret created
    [Arguments]    ${script_file}
    ${script_content}=    Get File    ${script_file}
    ${new_script}=    Catenate    SEPARATOR=\n    ${script_content}    echo "Secret key is: \$SECRET_KEY"
    RETURN    ${new_script}

Set Service File Script
    [Documentation]    Set the service script for the OSCAR service in the service file (generic)
    [Arguments]    ${service_content}    ${script_content}

    ${oscar_list}=    Get From Dictionary    ${service_content}[functions]    oscar

    ${first_service_item}=    Get From List    ${oscar_list}    0
    ${service_name}=    Get Dictionary Keys    ${first_service_item}
    ${service_name}=    Get From List    ${service_name}    0

    Set To Dictionary    ${first_service_item}[${service_name}]    script=${script_content}

    RETURN    ${service_content}

Set Service File Secret
    [Documentation]    Add secret to the OSCAR service in the service file (generic)
    [Arguments]    ${service_content}    ${secret_key}
    IF    '${secret_key}' == 'None' or '${secret_key}' == ''
        RETURN    ${service_content}
    END
    ${first_service_item}=    Get From List    ${service_content}[functions][oscar]    0
    ${service_name}=    Get Dictionary Keys    ${first_service_item}
    ${service_name}=    Get From List    ${service_name}    0

    ${secrets}=    Create Dictionary    SECRET_KEY    ${secret_key}
    ${environment}=    Create Dictionary    secrets    ${secrets}
    Set To Dictionary    ${first_service_item}[${service_name}]    environment=${environment}

    RETURN    ${service_content}

Set Service File Isolation Level
    [Documentation]    Set the isolation level for the OSCAR service in the service file (generic)
    [Arguments]    ${service_content}    ${isolation_level}

    ${first_service_item}=    Get From List    ${service_content}[functions][oscar]    0
    ${service_name}=    Get Dictionary Keys    ${first_service_item}
    ${service_name}=    Get From List    ${service_name}    0

    Set To Dictionary    ${first_service_item}[${service_name}]    isolation_level=${isolation_level}

    RETURN    ${service_content}

Set Service File Allowed Users
    [Documentation]    Set the allowed users for the OSCAR service in the service file (generic)
    [Arguments]    ${service_content}    @{allowed_users}

    ${first_service_item}=    Get From List    ${service_content}[functions][oscar]    0
    ${service_name}=    Get Dictionary Keys    ${first_service_item}
    ${service_name}=    Get From List    ${service_name}    0

    Set To Dictionary    ${first_service_item}[${service_name}]    allowed_users=@{allowed_users}

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

    # Get the first dictionary in the list
    ${first_service_item}=    Get From List    ${oscar_list}    0

    # Get the actual cluster/service name key dynamically
    ${service_names}=    Get Dictionary Keys    ${first_service_item}
    ${service_name}=    Get From List    ${service_names}    0

    # Get the cluster dict by the dynamic name
    ${cluster_dict}=    Get From Dictionary    ${first_service_item}    ${service_name}

    ${json_string}=    Evaluate    json.dumps(${cluster_dict})    json

    Create File    ${saved_file}    ${json_string}

Save YAML File
    [Documentation]    Save the service content to a YAML file
    [Arguments]    ${service_content}    ${saved_file}
    ${yaml_string}=    yaml.Safe Dump    ${service_content}
    Create File    ${saved_file}    ${yaml_string}
