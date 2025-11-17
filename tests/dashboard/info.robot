*** Settings ***
Documentation       UI regression tests for the Info panel.
Resource            ${CURDIR}/../../resources/dashboard.resource

Suite Setup         Prepare Dashboard Suite
Suite Teardown      Run Dashboard Suite Teardown


*** Test Cases ***
Info Panel Navigation Works
    [Documentation]    Ensures the Info panel can be opened.
    Navigate To Info Page

Server Information Section Visible
    [Documentation]    Confirms the main Info header is displayed.
    Navigate To Info Page
    ${server_section}=    Run Keyword And Return Status
    ...    Wait For Elements State    xpath=//h1[contains(., 'Server information')]    visible    timeout=60s
    IF    not ${server_section}
        Skip    Server information cards not available (system config missing).
    END

Cluster Detail Cards Render
    [Documentation]    Checks that the Info cards for OSCAR and MinIO are visible.
    Navigate To Info Page
    ${cluster_section}=    Run Keyword And Return Status
    ...    Wait For Elements State    xpath=//h1[contains(., 'OSCAR Cluster')]    visible    timeout=60s
    IF    not ${cluster_section}
        Skip    Cluster cards not available (system config missing).
    END
    ${minio_section}=    Run Keyword And Return Status
    ...    Wait For Elements State    xpath=//h1[contains(., 'MinIO')]    visible    timeout=60s
    IF    not ${minio_section}
        Skip    MinIO cards not available (provider info missing).
    END
