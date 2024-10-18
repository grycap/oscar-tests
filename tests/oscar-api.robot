*** Comments *** 

Tests for the OSCAR Manager's API of a deployed OSCAR cluster 
This test uses an OIDC token specified in the .env-* yaml file.
It can also obtain the OIDC token via oidc-agent, but it is disabled.

*** Settings ***

Library    BuiltIn
Library    RequestsLibrary
Library    Process
Library    OperatingSystem
Library    Collections
Library    DateTime
Resource   jwt.robot

*** Variables *** 

${OSCAR_ENDPOINT}=        %{oscar_endpoint}
${OIDC_AGENT_ACCOUNT}=    %{oidc_agent_account} 

# If you want to get the token from oidc-agent, 
# uncomment the line below and comment out the two lines after that
#${headers}

${ACCESS_TOKEN}=      %{access_token}
&{headers}=     Authorization=Bearer ${ACCESS_TOKEN}   Content-Type=text/json    Accept=application/json

*** Test Cases ***


Get Access Token
    [Documentation]    Retrieve OIDC token using oidc-agent and set as environment variable
    Skip    This test is disabled
    ${result}=    Run Process    oidc-token    ${OIDC_AGENT_ACCOUNT}    stdout=True    stderr=True
    ${oidc_token}=    Set Variable    ${result.stdout}     
    Log    OIDC Token: ${oidc_token}
    Set Environment Variable    ACCESS_TOKEN    ${oidc_token}
    Set Suite Variable    &{headers}    Authorization=Bearer ${oidc_token}   Content-Type=text/json    Accept=application/json
    
Check Valid Access Token
    Check JWT Expiration



OSCAR API health
    [Documentation]    OSCAR API health check should return status code 200 and body "Ok"
    ${response}=    GET  ${OSCAR_ENDPOINT}/health  expected_status=200
    Should Be Equal As Strings    ${response.content}    Ok


OSCAR List services 
   [Documentation]  OSCAR should retrieve a list of services 
   ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services    headers=${headers}


OSCAR Create service
    [Documentation]  OSCAR create a new service
    ${body}=    Get File    ./resources/00-cowsay.json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/system/services    data=${body}    headers=${headers}
    Sleep    10s


OSCAR Invoke service
    [Documentation]  OSCAR invoke the service
    ${body}=    Get File    ./resources/00-cowsay-invoke-body.json
    ${response}=    POST    url=${OSCAR_ENDPOINT}/run/robot-test-cowsay    data=${body}    headers=${headers}
    Log    ${response.content}
    Should Contain    ${response.content}    Hello


OSCAR Delete Service
    #Skip    This test is disabled
    [Documentation]  OSCAR delete the created service
    ${response}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/robot-test-cowsay   headers=${headers}
