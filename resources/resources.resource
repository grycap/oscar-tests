*** Settings ***
Documentation    General template for common variables and keywords used through the testing suite.

Library          Collections
Library          DateTime
Library          OperatingSystem
Library          Process
Library          JSONLibrary
Library          yaml


*** Variables ***
${OSCAR_ENDPOINT}=    ${OSCAR_ENDPOINT}
${REFRESH_TOKEN}=     ${REFRESH_TOKEN}
${TOKEN_URL}=         ${EGI_AAI_URL}
${TOKEN_ENDPOINT}=    /auth/realms/egi/protocol/openid-connect/token
${CLIENT_ID}=         token-portal
${SCOPE}=             openid%20email%20profile%20voperson_id%20eduperson_entitlement
${VO}=                ${EGI_VO}
${DATA_DIR}=          ${CURDIR}/../data
${SERVICE_FILE}=      ${DATA_DIR}/00-cowsay.yaml
${INVOKE_FILE}=       00-cowsay-invoke-body.json


*** Keywords ***
Get Access Token
    [Documentation]    Retrieve OIDC token using a refresh token
    ${result}=    Run Process    curl    -s    -X    POST    '${TOKEN_URL}${TOKEN_ENDPOINT}'    -d
    ...    'grant_type\=refresh_token&refresh_token\=${REFRESH_TOKEN}&client_id\=${CLIENT_ID}&scope\=${SCOPE}'
    ...    shell=True    stdout=True    stderr=True
    ${json_output}=    Convert String To Json    ${result.stdout}
    ${access_token}=    Get Value From Json    ${json_output}    $.access_token
    VAR    ${access_token}    ${access_token}[0]
    Log    Access Token: ${access_token}
    VAR    &{HEADERS}    Authorization=Bearer ${access_token}   Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    RETURN    ${access_token}

Decode JWT Token
    [Documentation]    Decode a JWT token and returns its payload
    [Arguments]    ${token}
    ${decoded}=    Evaluate
    ...    jwt.decode('${token}', options={"verify_signature": False}, algorithms=["HS256", "RS256"])
    RETURN   ${decoded}

Check JWT Expiration
    [Documentation]    Check if the given JWT token is expired
    [Arguments]    ${token}
    ${decoded_token}=    Decode JWT Token    ${token}
    Log    ${decoded_token}
    ${expiry_time}=    Get From Dictionary    ${decoded_token}    exp
    Log    Token Expiration Time: ${expiry_time}
    ${current_time}=    Get Current Date    result_format=epoch
    Log    Current Time: ${current_time}
    Should Be True    ${expiry_time} > ${current_time}    Token is expired

Modify Service File
    [Documentation]    Modify the service file with the VO
    ${yaml_content}=    Get File    ${SERVICE_FILE}
    ${loaded_content}=  yaml.Safe Load  ${yaml_content}
    Set To Dictionary    ${loaded_content}[functions][oscar][0][robot-oscar-cluster]    vo=${VO}
    RETURN    ${loaded_content}

Remove Files From Tests And Verify
    [Documentation]    Removes junk files generared in the tests
    [Arguments]    @{files}
    FOR    ${file}    IN    @{files}
        Remove File    ${file}
        File Should Not Exist    ${file}
    END

Set Service File For Update
    [Documentation]    Set the service file with the VO and set value
    [Arguments]  ${key}  ${value}
    ${yaml_content}=    Get File    ${SERVICE_FILE}
    ${loaded_content}=  yaml.Safe Load  ${yaml_content}
    Set To Dictionary    ${loaded_content}[functions][oscar][0][robot-oscar-cluster]    vo=${VO}
    Set To Dictionary    ${loaded_content}[functions][oscar][0][robot-oscar-cluster]    ${key}=${value}
    RETURN    ${loaded_content}

Verify Bucket
    [Documentation]    List all buckets
    ${response}=    GET    url=${OSCAR_ENDPOINT}/system/buckets    expected_status=200    headers=${HEADERS}
    RETURN      ${response}

Get Service File Update   
    [Documentation]    Prepare the service file
    [Arguments]    ${key}     ${value}
    ${service_content}=    Set Service File For Update      ${key}      ${value}

    # Extract the inner dictionary (remove 'functions', 'oscar' and 'robot-oscar-cluster')
    ${modified_content}=    Set Variable    ${service_content}[functions][oscar][0][robot-oscar-cluster]

    # Update the script value
    ${script_value}=    Catenate
    ...    \#!/bin/sh\n\nif [ \"$INPUT_TYPE\" = \"json\" ]\nthen\n
    ...    jq '.message' \"$INPUT_FILE_PATH\" -r | /usr/games/cowsay\nelse\n
    ...    cat \"$INPUT_FILE_PATH\" | /usr/games/cowsay\nfi\n\
    Set To Dictionary    ${modified_content}    script=${script_value}
    ${service_content_json}=    Evaluate    json.dumps(${modified_content})    json
    Create File    ${DATA_DIR}/service_file.json    ${service_content_json}
