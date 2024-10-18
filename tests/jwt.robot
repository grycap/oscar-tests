*** Comments *** 
Tests for JWT Validation

*** Settings ***
Library    Collections
Library    DateTime

*** Variables *** 

#${OSCAR_ENDPOINT}=        %{oscar_endpoint}
#${OIDC_AGENT_ACCOUNT}=    %{oidc_agent_account} 

# If you want to get the token from oidc-agent, 
# uncomment the line below and comment out the two lines after that
#${headers}

${ACCESS_TOKEN}=      %{access_token}
#&{headers}=     Authorization=Bearer ${ACCESS_TOKEN}   Content-Type=text/json    Accept=application/json


# Apparently, files with test cases, when imported by other Robot files, 
# the latter cannot reference the Keywords defined in the former
# 
#*** Test Cases ***

#Check Valid OIDC Token
#    Check JWT Expiration



*** Keywords ***

Check JWT Expiration
    [Documentation]    This test checks if the given JWT token is expired.
    ${decoded_token}=    Decode JWT Token    ${ACCESS_TOKEN}
    Log    ${decoded_token}
    ${expiry_time}=    Get From Dictionary    ${decoded_token}    exp
    Log    Token Expiration Time: ${expiry_time}
    ${current_time}=    Get Current Date    result_format=epoch
    Log    Current Time: ${current_time}
    Should Be True    ${expiry_time} > ${current_time}    Token is expired

Decode JWT Token
    [Documentation]    Decodes a JWT token and returns its payload.
    [Arguments]    ${token}
    ${decoded}=    Evaluate    jwt.decode('${token}', options={"verify_signature": False}, algorithms=["HS256", "RS256"])
    RETURN   ${decoded}