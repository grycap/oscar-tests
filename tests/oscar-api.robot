*** Comments *** 
Tests for the OSCAR Manager's API of a deployed OSCAR cluster 

*** Settings ***
Library    RequestsLibrary
Library    Process
Library    OperatingSystem

*** Variables *** 

${OSCAR_ENDPOINT}=        %{oscar_endpoint}
${OIDC_AGENT_ACCOUNT}=    %{oidc_agent_account} 
${headers}

#${ACCESS_TOKEN}=      %{access_token}
#&{headers}=     Authorization=Bearer ${ACCESS_TOKEN}   Content-Type=text/json    Accept=application/json

*** Test Cases ***

Get Access Token
    [Documentation]    Retrieve OIDC token using oidc-agent and set as environment variable
    ${result}=    Run Process    oidc-token    ${OIDC_AGENT_ACCOUNT}    stdout=True    stderr=True
    ${oidc_token}=    Set Variable    ${result.stdout}     
    Log    OIDC Token: ${oidc_token}
    Set Environment Variable    ACCESS_TOKEN    ${oidc_token}
    Set Suite Variable    &{headers}    Authorization=Bearer ${oidc_token}   Content-Type=text/json    Accept=application/json
    
OSCAR API health
    [Documentation]    OSCAR API health check should return status code 200 and body "Ok"
    ${response}=    GET  ${OSCAR_ENDPOINT}/health  expected_status=200
    Should Be Equal As Strings    ${response.content}    Ok


OSCAR List services 
   [Documentation]  OSCAR should retrieve a list of services 
   ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services    headers=${headers}

