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
${SCRIPT_FILE}          ${DATA_DIR}/00-cowsay-script.sh


*** Keywords ***
Load Original Service File
    [Documentation]    Load the original service file and return its content
    [Arguments]    ${filename}
    ${yaml_content}=    Get File    ${filename}
    ${loaded_content}=    yaml.Safe Load    ${yaml_content}
    RETURN    ${loaded_content}

Set Service Script
    [Documentation]    Set the service script for the OSCAR service
    [Arguments]    ${service_content}
    ${oscar_list}=    Get From Dictionary    ${service_content}[functions]    oscar
    ${modified_content}=    Get From Dictionary    ${oscar_list}[0]    robot-oscar-cluster

    ${script}=    Catenate
    ...    \#!/bin/sh\n\nif [ \"$INPUT_TYPE\" = \"json\" ]\nthen\n
    ...    jq '.message' \"$INPUT_FILE_PATH\" -r | /usr/games/cowsay\nelse\n
    ...    cat \"$INPUT_FILE_PATH\" | /usr/games/cowsay\nfi\n\
    Set To Dictionary    ${modified_content}    script=${script}
    RETURN    ${service_content}

Set VO
    [Documentation]    Set the VO for the OSCAR service
    [Arguments]    ${service_content}
    Set To Dictionary    ${service_content}[functions][oscar][0][robot-oscar-cluster]    vo=${VO}
    RETURN    ${service_content}

Set Isolation Level
    [Documentation]    Set the isolation level for the OSCAR service
    [Arguments]    ${service_content}    # ${allowed_users}
    Set To Dictionary    ${service_content}[functions][oscar][0][robot-oscar-cluster]    isolation_level=RESTRICTED
    # Set To Dictionary    ${service_content}[functions][oscar][0][robot-oscar-cluster]    allowed_users=${allowed_users}
    RETURN    ${service_content}

Dump Service To JSON File
    [Documentation]    Dump the service content to a JSON file
    [Arguments]    ${service_content}    ${output_file}
    ${oscar_list}=    Get From Dictionary    ${service_content}[functions]    oscar
    ${cluster_dict}=    Get From Dictionary    ${oscar_list}[0]    robot-oscar-cluster
    ${json_string}=    Evaluate    json.dumps(${cluster_dict})    json
    Create File    ${output_file}    ${json_string}

Save YAML File
    [Documentation]    Save the service content to a YAML file
    [Arguments]    ${service_content}    ${output_file}
    ${yaml_string}=    yaml.Safe Dump    ${service_content}
    Create File    ${output_file}    ${yaml_string}

Get Key From Dictionary
    [Documentation]    Get the key from a dictionary
    [Arguments]    ${dict}
    ${keys}=    Get Dictionary Keys    ${dict}
    IF    not ${keys}    Fail    The dictionary is empty. Cannot extract job.
    VAR    ${JOB_NAME}=    ${keys}[0]    scope=SUITE
    RETURN    ${JOB_NAME}

Clean Test Artifacts
    [Documentation]    Removes junk files generared in the tests
    [Arguments]    @{files}
    FOR    ${file}    IN    @{files}
        Remove File    ${file}
        File Should Not Exist    ${file}
    END
