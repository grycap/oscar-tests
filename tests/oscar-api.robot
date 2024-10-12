*** Comments *** 
Tests for the OSCAR Manager's API of a deployed OSCAR cluster 

*** Settings ***
Library    RequestsLibrary

*** Variables *** 

${OSCAR_ENDPOINT}=    %{oscar_endpoint}
${ACCESS_TOKEN}=      %{access_token}
&{headers}=     Authorization=Bearer ${ACCESS_TOKEN}   Content-Type=text/json    Accept=application/json

*** Test Cases ***

OSCAR API health
    [Documentation]    OSCAR API health check should return status code 200 and body "Ok"
    ${response}=    GET  ${OSCAR_ENDPOINT}/health  expected_status=200
    Should Be Equal As Strings    ${response.content}    Ok


OSCAR List services 
   [Documentation]  OSCAR should retrieve a list of services 
   ${response}=    GET    url=${OSCAR_ENDPOINT}/system/services    headers=${headers}
