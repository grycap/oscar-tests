*** Settings ***
Documentation     Tests for the OSCAR Manager's API of a deployed OSCAR cluster.

Library           RequestsLibrary
Resource          ${CURDIR}/../../${AUTHENTICATION_PROCESS} 
Resource          ${CURDIR}/../../resources/files.resource
Resource          ${CURDIR}/../../resources/service.resource

Suite Setup       Run Keywords    Checks Valids OIDC Token    AND    Assign Random Service Name
Suite Teardown    Clean Test Artifacts    True    ${DATA_DIR}/service_file.json

*** Variables ***
${SERVICE_BASE}     robot-test-cowsay
${SERVICE_NAME}     ${SERVICE_BASE}
${BUCKET_NAME}      ${SERVICE_NAME}


*** Test Cases ***

OSCAR API Health
    [Documentation]    Check API health
    ${response}=    GET  ${OSCAR_ENDPOINT}/health  expected_status=200
    Log    ${response.content}
    Should Be Equal As Strings    ${response.content}    Ok

OSCAR Create Service
    [Documentation]  Create a new service
    Prepare Service File
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services   expected_status=201    data=${body}
    ...                     headers=${HEADERS}
    Log    ${response}  
    Log    ${response.content} 
    Should Be Equal As Strings    ${response.status_code}    201

Verify Visibility of service and check the Bucket is private
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${BUCKET_NAME}","visibility":"private"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}
    Verify Asynchronous works       ${HEADERS}


OSCAR Update Service visibility private -> restricted
    [Documentation]  Update a service private -> restricted
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${USER}
    Append To List      ${users}    ${OTHER_USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${body}=    Update File     ${body}      visibility     restricted
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Verify Visibility of service and check the Bucket is updated to restricted from private
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${BUCKET_NAME}","visibility":"restricted"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    Should Contain       ${response}      ${service_name}
    Verify Asynchronous works       ${HEADERS}
    Verify Asynchronous works       ${HEADERS2}


OSCAR Update Service visibility restricted -> public
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${body}=    Update File     ${body}      visibility     public
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Verify Visibility of service and check the Bucket is updated to public from restricted
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${BUCKET_NAME}","visibility":"public"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    Should Contain       ${response}      ${service_name}
    Verify Asynchronous works       ${HEADERS}
    Verify Asynchronous works       ${HEADERS2}

OSCAR Update Service visibility public -> private
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${body}=    Update File     ${body}      visibility     private
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Verify Visibility of service and check the Bucket is updated to private from public
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${BUCKET_NAME}","visibility":"private"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}
    Verify Asynchronous works       ${HEADERS}

OSCAR Update Service private -> public
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${body}=    Update File     ${body}      visibility     public
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Verify Visibility of service and check the Bucket is updated to public from private
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${BUCKET_NAME}","visibility":"public"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    Should Contain       ${response}      ${service_name}
    Verify Asynchronous works       ${HEADERS}
    Verify Asynchronous works       ${HEADERS2}

OSCAR Update Service visibility public -> restricted
    [Documentation]  Update a service public -> restricted
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${body}=    Update File     ${body}      visibility     restricted
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'

Verify Visibility of service and check the Bucket is updated to restricted from public
    [Documentation]    Buckets 
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${BUCKET_NAME}","visibility":"restricted"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}
    Verify Asynchronous works       ${HEADERS}

OSCAR Update Service visibility restricted -> private
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${body}=    Update File     ${body}      visibility     private
    ${response}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${HEADERS}
    Log    ${response.content}
    Should Be True    '${response.status_code}' == '200' or '${response.status_code}' == '204'


Verify Visibility of service and check the Bucket is updated to private from restricted
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${BUCKET_NAME}","visibility":"private"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}
    Verify Asynchronous works       ${HEADERS}


OSCAR Delete Service private
    [Documentation]  Delete the created service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${service_name}   expected_status=204
    ...                       headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Verify if private Bucket is deleted 
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    ${output} = 	Convert To String 	${response.status_code}
    Should Not Match Regexp    ${output}    ${BUCKET_NAME}
    ${response}=    Get Services        ${HEADERS}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}

OSCAR Create Service restricted
    [Documentation]  Create a new service
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${USER}
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${body}=    Update File     ${body}      visibility     restricted
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services   expected_status=201    data=${body}
    ...                     headers=${HEADERS}
    Log    ${response}  
    Log    ${response.content} 
    Should Be Equal As Strings    ${response.status_code}    201

Verify Visibility of service and check the Bucket is restricted
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${BUCKET_NAME}","visibility":"restricted"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}
    Verify Asynchronous works       ${HEADERS}


OSCAR Delete Service restricted
    [Documentation]  Delete the created service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${service_name}   expected_status=204
    ...                       headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Verify if restricted Bucket is deleted 
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    ${output} = 	Convert To String 	${response.status_code}
    Should Not Match Regexp    ${output}    ${BUCKET_NAME}
    ${response}=    Get Services        ${HEADERS}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}

OSCAR Create Service public
    [Documentation]  Create a new service
    ${body}=    Get File    ${DATA_DIR}/service_file.json
    ${users}=       Create List     ${USER}
    ${body}=    Update File     ${body}      visibility     public
    ${body}=    Update File     ${body}      allowed_users     ${users}
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services   expected_status=201    data=${body}
    ...                     headers=${HEADERS}
    Log    ${response}  
    Log    ${response.content} 
    Should Be Equal As Strings    ${response.status_code}    201

Verify Visibility of service and check the Bucket is public
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    Should Contain    ${response.content}    "bucket_name":"${BUCKET_NAME}","visibility":"public"
    ${response}=    Get Services        ${HEADERS}
    Should Contain       ${response}      ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    Should Contain       ${response}      ${service_name}
    Verify Asynchronous works       ${HEADERS}
    Verify Asynchronous works       ${HEADERS2}


OSCAR Delete Service public
    [Documentation]  Delete the created service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${service_name}   expected_status=204
    ...                       headers=${HEADERS}
    Log    ${response.content}
    Should Be Equal As Strings    ${response.status_code}    204

Verify if public Bucket is deleted 
    ${response}=    Verify Bucket
    Should Be Equal As Strings    ${response.status_code}    200
    ${output} = 	Convert To String 	${response.status_code}
    Should Not Match Regexp    ${output}    ${BUCKET_NAME}
    ${response}=    Get Services        ${HEADERS}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}
    ${response}=    Get Services        ${HEADERS2}
    ${output} = 	Convert To String 	${response}
    Should Not Match Regexp    ${output}    ${service_name}


*** Keywords ***
Get Key From Dictionary
    [Documentation]  Get the key from a dictionary
    [Arguments]    ${dict}
    ${keys}=    Get Dictionary Keys    ${dict}
    IF    not ${keys}    Fail    The dictionary is empty. Cannot extract job.
    ${JOB_NAME}=    Get From List    ${keys}    0
    VAR    ${JOB_NAME}    ${keys}[0]    scope=SUITE
    RETURN    ${JOB_NAME}

Prepare Service File
    [Documentation]    Prepare the service file
    ${service_content}=    Modify Service File  

    # Extract the inner dictionary (remove 'functions', 'oscar' and 'robot-oscar-cluster')
    ${modified_content}=    Set Variable    ${service_content}[functions][oscar][0][robot-oscar-cluster]

    # Update the script value
    ${script_value}=    Catenate
    ...    \#!/bin/sh\n\nif [ \"$INPUT_TYPE\" = \"json\" ]\nthen\n
    ...    jq '.message' \"$INPUT_FILE_PATH\" -r | /usr/games/cowsay\nelse\n
    ...    cat \"$INPUT_FILE_PATH\" | /usr/games/cowsay\nfi\n\
    Set To Dictionary    ${modified_content}    script=${script_value}
    Set To Dictionary    ${modified_content}    script=${script_value}
    Set To Dictionary    ${modified_content}    name=${SERVICE_NAME}
    ${input_entries}=    Get From Dictionary    ${modified_content}    input
    ${first_input}=    Get From List    ${input_entries}    0
    Set To Dictionary    ${first_input}    path=${SERVICE_NAME}/input
    ${output_entries}=    Get From Dictionary    ${modified_content}    output
    ${first_output}=    Get From List    ${output_entries}    0
    Set To Dictionary    ${first_output}    path=${SERVICE_NAME}/output
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${DATA_DIR}/service_file.json    ${service_content_json}


Update File
    [Arguments]    ${content}       ${key}      ${value}
    ${loaded_content}=  yaml.Safe Load  ${content}
    Set To Dictionary    ${loaded_content}      ${key}=${value}
    ${service_content_json}=    Evaluate    json.dumps(${loaded_content})    json
    RETURN      ${service_content_json}

Modify Service File
    [Documentation]    Modify the service file with the VO
    ${yaml_content}=    Get File    ${DATA_DIR}/00-cowsay.yaml
    ${loaded_content}=  yaml.Safe Load  ${yaml_content}
    Set To Dictionary    ${loaded_content}[functions][oscar][0][robot-oscar-cluster]    vo=${VO}
    RETURN    ${loaded_content}

Get Services
    [Arguments]    ${header_options} 
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services    expected_status=200    headers=${header_options}
    RETURN      ${response.content}

Verify Asynchronous works
    [Documentation]    Invoke the asynchronous service
    [Arguments]    ${header_options}
    Skip If    '${LOCAL_TESTING}'=='True'    #Skipping in favour of the next one which uses the service token
    ${body}=    Get File    ${INVOKE_FILE}
    ${response}=    POST     url=${OSCAR_ENDPOINT}/job/${SERVICE_NAME}     data=${body}     headers=${header_options}
    Should Be Equal As Strings    ${response.status_code}    201
    ${list_jobs}=    GET        url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}   headers=${header_options}
    ${jobs_dict}=    Evaluate    dict(${list_jobs.content})
    Get Key From Dictionary    ${jobs_dict["jobs"]}
    Should Contain    ${JOB_NAME}    ${SERVICE_NAME}-
    FOR    ${i}    IN RANGE    ${MAX_RETRIES}
        ${status}    ${resp}=    Run Keyword And Ignore Error    GET         url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}/${JOB_NAME}   headers=${header_options}
        IF    '${status}' != 'FAIL'
            ${status}=    Run Keyword And Return Status    Should Contain    ${resp.content}    Hello
            Exit For Loop If    ${status}
        END
        Sleep   ${RETRY_INTERVAL}
    END
    Log    Exited
    ${delete_logs}=    DELETE         url=${OSCAR_ENDPOINT}/system/logs/${SERVICE_NAME}/${JOB_NAME}   headers=${header_options}
    Should Be Equal As Strings    ${response.status_code}    201