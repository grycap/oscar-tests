*** Settings ***
Documentation       UI regression tests for the Notebooks panel.
Resource            ${CURDIR}/../../resources/dashboard.resource

Suite Setup         Prepare Dashboard Suite
Suite Teardown      Run Dashboard Suite Teardown


*** Test Cases ***
Notebooks Panel Navigation Works
    [Documentation]    Ensures the Notebooks panel can be opened.
    Navigate To Notebooks Page

Notebooks Table Columns Visible
    [Documentation]    Checks that the Notebooks table renders expected columns.
    Navigate To Notebooks Page
    Wait For Elements State    xpath=//th[normalize-space()='Name']    visible    timeout=10s
    Wait For Elements State    xpath=//th[normalize-space()='Image']    visible    timeout=10s
    Wait For Elements State    xpath=//th[normalize-space()='CPU']    visible    timeout=10s

New Notebook Button Is Present
    [Documentation]    Verifies that users can trigger new notebook instances.
    Navigate To Notebooks Page
    Wait For Elements State    role=button[name="New"]    visible    timeout=10s
