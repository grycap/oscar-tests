*** Comments *** 

Tests for the OSCAR's metrics endpoint.


*** Settings ***

Library        RequestsLibrary
Resource        ../resources/resources.robot


*** Test Cases ***

OSCAR metrics
    [Documentation]    Check that metrics for OSCAR are updated
    ${response}=    GET    ${OSCAR_METRICS}    expected_status=200
    Log    ${response.json()}[general]
    ${current_date_time}=    Get Current Date
    ${metrics_date_time}=    Set Variable    ${response.json()}[general][date_time]
    ${adjusted_metrics_time}=    Add Time To Date    ${metrics_date_time}    2 days
    ${metrics_updated}=    Evaluate    '${adjusted_metrics_time}' > '${current_date_time}'
    Should Be True    ${metrics_updated}