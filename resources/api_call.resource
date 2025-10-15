*** Settings ***
Documentation       Shared keywords and variables for handling OIDC authentication

Library             Collections
Library             DateTime
Library             Process
Library             RequestsLibrary
Library             JSONLibrary



*** Keywords ***


GET With Defaults
    [Arguments]    ${url}    ${expected_status}=200   ${headers}=${HEADERS}
    ${headers}=    Run Keyword If    '${LOCAL_TESTING}'=='True'    Set Variable    ${HEADERS_OSCAR}    ELSE    Set Variable    ${headers}    
    ${response}=    GET    url=${url}    expected_status=${expected_status}    verify=${SSL_VERIFY}    headers=&{headers}
    RETURN    ${response}

POST With Defaults
    [Arguments]    ${url}    ${data}     ${headers}=${HEADERS}
    ${headers}=    Run Keyword If    '${LOCAL_TESTING}'=='True'    Set Variable    ${HEADERS_OSCAR}    ELSE    Set Variable    ${headers}    
    ${response}=    POST    url=${url}    data=${data}    expected_status=ANY  verify=${SSL_VERIFY}    headers=&{headers}
    RETURN    ${response}

PUT With Defaults
    [Arguments]    ${url}    ${data}    ${expected_status}=204   ${headers}=${HEADERS}
    ${headers}=    Run Keyword If    '${LOCAL_TESTING}'=='True'    Set Variable    ${HEADERS_OSCAR}    ELSE    Set Variable    ${headers}    
    ${response}=    PUT    url=${url}    data=${data}    expected_status=${expected_status}    verify=${SSL_VERIFY}    headers=&{headers}
    RETURN    ${response}

DELETE With Defaults
    [Arguments]    ${url}    ${expected_status}=204   ${headers}=${HEADERS}
    ${headers}=    Run Keyword If    '${LOCAL_TESTING}'=='True'    Set Variable    ${HEADERS_OSCAR}    ELSE    Set Variable    ${headers}    
    ${response}=    DELETE    url=${url}    expected_status=${expected_status}    verify=${SSL_VERIFY}    headers=&{headers}
    RETURN    ${response}