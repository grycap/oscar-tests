*** Settings ***
Documentation       UI regression tests for the Services panel.
Resource            ${CURDIR}/../../resources/dashboard.resource

Suite Setup         Prepare Dashboard Suite
Suite Teardown      Run Dashboard Suite Teardown


*** Test Cases ***
Services Panel Loads By Default
    [Documentation]    Ensures the Services panel is visible after authentication.
    Wait For Dashboard Route    services

Service Filter Allows Typing
    [Documentation]    Validates that the filter field can be interacted with.
    Navigate To Services Page
    Wait For Elements State    css=input[placeholder^="Filter by"]    visible    timeout=10s
    ${query}=    Set Variable    test-service-filter
    Fill Text    css=input[placeholder^="Filter by"]    ${query}
    ${value}=    Get Attribute    css=input[placeholder^="Filter by"]    value
    Should Be Equal    ${value}    ${query}

Services Table Shows Key Columns
    [Documentation]    Checks that the Services table renders the main columns.
    Navigate To Services Page
    Wait For Elements State    xpath=//th[normalize-space()='Name']    visible    timeout=10s
    Wait For Elements State    xpath=//th[normalize-space()='Image']    visible    timeout=10s
    Wait For Elements State    xpath=//th[normalize-space()='CPU']    visible    timeout=10s
    Wait For Elements State    xpath=//th[normalize-space()='Memory']    visible    timeout=10s
