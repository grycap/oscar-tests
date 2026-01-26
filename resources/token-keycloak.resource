*** Settings ***
Documentation       Shared keywords and variables for handling OIDC authentication

Library             Collections
Library             DateTime
Library             Process
Library             RequestsLibrary
Library             JSONLibrary
Library             String


*** Variables ***
${TOKEN_URL}            ${AAI_URL}/protocol/openid-connect/token    
${USERINFO_URL}         ${AAI_URL}/protocol/openid-connect/userinfo 
${CLIENT_ID}            ${CLIENT_ID}
${SCOPE}                ${SCOPE}
${KEYCLOAK_USERNAME}    ${KEYCLOAK_USERNAME}
${KEYCLOAK_PASSWORD}    ${KEYCLOAK_PASSWORD}

*** Keywords ***
Check Valid OIDC Token
    [Documentation]    Get the access token
    [Tags]    create    delete
    ${token}=    Get Access Token
    Check JWT Expiration    ${token}

Set Refresh Token 
    [Documentation]    Get the refresh token
    ${result}=    Run Process    curl  -s  -X    POST    '${TOKEN_URL}'   -d
    ...     'grant_type\=password&username\=${KEYCLOAK_USERNAME}&password\=${KEYCLOAK_PASSWORD}&client_id\=${CLIENT_ID}&scope\=${SCOPE}'
    ...     shell=True    stdout=True    stderr=True
    ${json_output}=    Convert String To Json    ${result.stdout}
    ${refresh_token}=    Get Value From Json    ${json_output}    $.refresh_token
    VAR     ${REFRESH_TOKEN}=       ${refresh_token}[0]
    ${access_token}=    Get Value From Json    ${json_output}    $.access_token
    VAR    ${access_token}=    ${access_token}[0]
    Log    Access Token: ${access_token}
    VAR    &{HEADERS}=    Authorization=Bearer ${access_token}    Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    VAR    &{HEADERS_OSCAR}=    Authorization=Basic ${BASIC_USER}    Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    ${user_info}=    GET    url=${USERINFO_URL}    headers=${HEADERS}
    ${json_output}=    Convert String To Json    ${user_info.content}
    ${user_id}=    Get Value From Json    ${json_output}    $.sub
    Set Global Variable    ${USER}    ${user_id}[0]
    Set Global Variable    ${USER_SHORT_ID}    ${USER}[0:10]
    Set Global Variable    ${REFRESH_TOKEN}

Get Access Token
    [Documentation]    Retrieve OIDC token using a refresh token
    ${result}=    Run Process    curl  -s  -X    POST    '${TOKEN_URL}'   -d
    ...     'grant_type\=password&username\=${KEYCLOAK_USERNAME}&password\=${KEYCLOAK_PASSWORD}&client_id\=${CLIENT_ID}&scope\=${SCOPE}'
    ...     shell=True    stdout=True    stderr=True
    ${json_output}=    Convert String To Json    ${result.stdout}
    ${access_token}=    Get Value From Json    ${json_output}    $.access_token
    VAR    ${access_token}=    ${access_token}[0]
    Log    Access Token: ${access_token}
    VAR    &{HEADERS}=    Authorization=Bearer ${access_token}    Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    VAR    &{HEADERS_OSCAR}=    Authorization=Basic ${BASIC_USER}    Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    ${user_info}=    GET    url=${USERINFO_URL}    headers=${HEADERS}
    ${json_output}=    Convert String To Json    ${user_info.content}
    ${user_id}=    Get Value From Json    ${json_output}    $.sub
    Set Global Variable    ${USER}    ${user_id}[0]
    Set Global Variable    ${USER_SHORT_ID}    ${USER}[0:10]
    RETURN    ${access_token}

Decode JWT Token
    [Documentation]    Decode a JWT token and returns its payload
    [Arguments]    ${token}
    ${decoded}=    Evaluate
    ...    jwt.decode('${token}', options={"verify_signature": False}, algorithms=["HS256", "RS256"])
    RETURN    ${decoded}

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


Checks Valids OIDC Token
    [Documentation]    Get the access token
    ${result}=    Run Process    curl  -s  -X    POST    '${TOKEN_URL}'   -d
    ...     'grant_type\=password&username\=${KEYCLOAK_USERNAME}&password\=${KEYCLOAK_PASSWORD}&client_id\=${CLIENT_ID}&scope\=${SCOPE}'
    ...     shell=True    stdout=True    stderr=True
    ${json_output}=    Convert String To Json    ${result.stdout}
    ${access_token}=    Get Value From Json    ${json_output}    $.access_token
    VAR    ${access_token}=    ${access_token}[0]
    Log    Access Token: ${access_token}
    VAR    &{HEADERS}=    Authorization=Bearer ${access_token}    Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    VAR    &{HEADERS_OSCAR}=    Authorization=Basic ${BASIC_USER}    Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    ${user_info}=    GET    url=${USERINFO_URL}    headers=${HEADERS}
    ${json_output}=    Convert String To Json    ${user_info.content}
    ${user_id}=    Get Value From Json    ${json_output}    $.sub
    Set Global Variable    ${USER}    ${user_id}[0]
    Set Global Variable    ${USER_SHORT_ID}    ${USER}[0:10]
    ${result}=    Run Process    curl  -s  -X    POST    '${TOKEN_URL}'   -d
    ...     'grant_type\=password&username\=${KEYCLOAK_USERNAME_AUX}&password\=${KEYCLOAK_PASSWORD_AUX}&client_id\=${CLIENT_ID}&scope\=${SCOPE}'
    ...     shell=True    stdout=True    stderr=True
    ${json_output}=    Convert String To Json    ${result.stdout}
    ${access_token}=    Get Value From Json    ${json_output}    $.access_token
    VAR    ${access_token}=    ${access_token}[0]
    Log    Access Token: ${access_token}
    VAR    &{HEADERS2}=    Authorization=Bearer ${access_token}    Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    VAR    &{HEADERS_OSCAR}=    Authorization=Basic ${BASIC_USER}    Content-Type=text/json    Accept=application/json
    ...    scope=SUITE
    ${user_info}=    GET    url=${USERINFO_URL}    headers=${HEADERS2}
    ${json_output}=    Convert String To Json    ${user_info.content}
    ${user_id}=    Get Value From Json    ${json_output}    $.sub
    Set Global Variable    ${OTHER_USER}    ${user_id}[0]
    Set Global Variable    ${OTHER_USER_SHORT_ID}    ${OTHER_USER}[0:10]