*** Comments *** 
Tests for the OSCAR CLI agains a deployed OSCAR cluster

*** Settings ***
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
    #Skip    This test is disabled
    ${result}=    Run Process    oidc-token    ${OIDC_AGENT_ACCOUNT}  
    ${oidc_token}=    Set Variable    ${result.stdout}     
    Log    OIDC Token: ${oidc_token}
    Set Environment Variable    ACCESS_TOKEN    ${oidc_token}
    Set Suite Variable    &{headers}    Authorization=Bearer ${oidc_token}   Content-Type=text/json    Accept=application/json
    
OSCAR CLI installed
    [Documentation]    Check that OSCAR CLI is installed
    ${result}=    Run Process    oscar-cli   
    Log    ${result}
    Should Contain    ${result.stdout}    apply


OSCAR CLI add cluster
    [Documentation]    Check that OSCAR CLI add cluster works
    ${result}=    Run Process    oscar-cli    add    robot-oscar-cluster ${OSCAR_ENDPOINT} --oidc-account-name  ${OIDC_AGENT_ACCOUNT} --config /Users/gmolto/Documents/GitHub/grycap/oscar-tests/robot-oscar-cluster-config.yaml 
    Log    ${result}

OSCAR CLI list services 
    [Documentation]    Check that OSCAR CLI returns a list of services
    ${result}=    Run Process    oscar-cli   



