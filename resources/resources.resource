*** Settings ***
Documentation    General template for common variables and keywords used through the testing suite.

Library    Collections
Library    DateTime
Library    Process
Library    OperatingSystem
Library    JSONLibrary


*** Variables *** 
${OSCAR_ENDPOINT}=    %{OSCAR_ENDPOINT}
${TOKEN_URL}=         %{TOKEN_URL}
${REFRESH_TOKEN}=     %{REFRESH_TOKEN}
${CLIENT_ID}=         token-portal
${SCOPE}=             openid%20email%20profile%20voperson_id%20eduperson_entitlement


*** Keywords ***
Get Access Token
    [Documentation]    Retrieve OIDC token using a refresh token
    ${result}=    Run Process    curl    -s    -X    POST    '${TOKEN_URL}'    -d    
    ...    'grant_type\=refresh_token&refresh_token\=${REFRESH_TOKEN}&client_id\=${CLIENT_ID}&scope\=${SCOPE}'    
    ...    |    python    -m    json.tool;    shell=True    stdout=True    stderr=True
    ${json_output}=    Convert String To Json    ${result.stdout}
    ${access_token}=    Get Value From Json    ${json_output}    $.access_token
    ${access_token}    Set Variable    ${access_token}[0]
    Log    Access Token: ${access_token}
    Set Suite Variable    &{HEADERS}    Authorization=Bearer ${access_token}   Content-Type=text/json    
    ...    Accept=application/json
    Set Suite Variable    ${access_token}
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

Remove Files From Tests And Verify
    [Arguments]    @{files}
    FOR    ${file}    IN    @{files}
        Remove File    ${file}
        File Should Not Exist    ${file}
    END