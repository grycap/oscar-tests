*** Comments *** 

General template for common variables and keywords used through the testing suite.


*** Settings ***

Library    Collections
Library    DateTime
Library    Process
Library    OperatingSystem


*** Variables *** 

${OSCAR_ENDPOINT}=        %{oscar_endpoint}
${OIDC_AGENT_ACCOUNT}=    %{oidc_agent_account} 
${OSCAR_METRICS}=        %{oscar_metrics}

${headers}


*** Keywords ***

Get Access Token
    [Documentation]    Retrieve OIDC token using oidc-agent
    ${result}=    Run Process    oidc-token    ${OIDC_AGENT_ACCOUNT}    stdout=True    stderr=True
    ${oidc_token}=    Set Variable    ${result.stdout}     
    Log    OIDC Token: ${oidc_token}
    Set Suite Variable    &{headers}    Authorization=Bearer ${oidc_token}   Content-Type=text/json    Accept=application/json
    RETURN    ${oidc_token}

Decode JWT Token
    [Documentation]    Decode a JWT token and returns its payload.
    [Arguments]    ${token}
    ${decoded}=    Evaluate    jwt.decode('${token}', options={"verify_signature": False}, algorithms=["HS256", "RS256"])
    RETURN   ${decoded}

Check JWT Expiration
    [Documentation]    Check if the given JWT token is expired.
    [Arguments]    ${token}
    ${decoded_token}=    Decode JWT Token    ${token}
    Log    ${decoded_token}
    ${expiry_time}=    Get From Dictionary    ${decoded_token}    exp
    Log    Token Expiration Time: ${expiry_time}
    ${current_time}=    Get Current Date    result_format=epoch
    Log    Current Time: ${current_time}
    Should Be True    ${expiry_time} > ${current_time}    Token is expired

Remove files from tests and verify
    [Arguments]    ${file}
    Remove File    ${file}
    File Should Not Exist    ${file}