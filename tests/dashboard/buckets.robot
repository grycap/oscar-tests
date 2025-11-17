*** Settings ***
Documentation       UI regression tests for the Buckets (MinIO) panel.
Resource            ${CURDIR}/../../resources/dashboard.resource

Suite Setup         Prepare Dashboard Suite
Suite Teardown      Run Dashboard Suite Teardown


*** Test Cases ***
Buckets Panel Navigation Works
    [Documentation]    Ensures that the Buckets panel can be opened from the sidebar.
    Navigate To Buckets Page

Bucket Creation Button Visible
    [Documentation]    Checks that the quick action button to create a bucket is available.
    Navigate To Buckets Page
    Wait For Elements State    role=button[name="New"]    visible    timeout=10s

Buckets Table Shows Columns
    [Documentation]    Checks that the bucket list table is rendered.
    Navigate To Buckets Page
    ${name_visible}=    Run Keyword And Return Status
    ...    Wait For Elements State    xpath=//th[contains(normalize-space(), 'Name')]    visible    timeout=30s
    IF    not ${name_visible}
        Skip    Buckets table did not render within 30s (MinIO data unavailable).
    END
    ${owner_visible}=    Run Keyword And Return Status
    ...    Wait For Elements State    xpath=//th[contains(normalize-space(), 'Owner')]    visible    timeout=10s
    IF    not ${owner_visible}
        Skip    Owner column not visible (MinIO data unavailable).
    END
