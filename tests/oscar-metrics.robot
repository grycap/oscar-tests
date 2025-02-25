*** Settings ***
Documentation    Tests for the OSCAR's metrics endpoint.

Library          DateTime
Library          RequestsLibrary


*** Variables ***
${OSCAR_METRICS}=         ${OSCAR_METRICS}


*** Test Cases ***
OSCAR Metrics
    [Documentation]    Check that metrics for OSCAR are updated
    ${response}=    GET    ${OSCAR_METRICS}    expected_status=200
    Log    ${response.json()}[general]
    ${current_date_time}=    Get Current Date
    VAR    ${metrics_date_time}    ${response.json()}[general][date_time]
    ${adjusted_metrics_time}=    Add Time To Date    ${metrics_date_time}    2 days
    ${metrics_updated}=    Evaluate    '${adjusted_metrics_time}' > '${current_date_time}'
    Should Be True    ${metrics_updated}    Metrics were updated less than 2 days ago
