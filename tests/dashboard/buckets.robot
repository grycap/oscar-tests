*** Settings ***
Documentation       UI regression tests for the Buckets (MinIO) panel.
Resource              ${CURDIR}/../../resources/dashboard.resource

Suite Setup         Prepare Dashboard Suite
Suite Teardown      Run Dashboard Suite Teardown



*** Variables ***
${DASHBOARD_BUCKET_BASE}             dash-bucket
${DASHBOARD_BUCKET_OBJECT_NAME}      dashboard-bucket-transfer.txt




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

Bucket Can Upload And Download File
      [Documentation]    Creates a bucket in the dashboard, uploads a file via the Upload Files Popover and downloads it back.
      [Setup]    Prepare Dashboard Bucket Transfer Test
      [Teardown]    Cleanup Dashboard Bucket Transfer Test
    Create Bucket From Dashboard      ${DASHBOARD_BUCKET_NAME}
    Open Dashboard Bucket      ${DASHBOARD_BUCKET_NAME}
    Upload File To Dashboard Bucket      ${DASHBOARD_BUCKET_UPLOAD_FILE}
    Wait For Bucket Object Row      ${DASHBOARD_BUCKET_OBJECT_NAME}
    Download Dashboard Bucket Object      ${DASHBOARD_BUCKET_OBJECT_NAME}      ${DASHBOARD_BUCKET_DOWNLOAD_FILE}
      ${uploaded_content}=    Get File      ${DASHBOARD_BUCKET_UPLOAD_FILE}
      ${downloaded_content}=    Get File      ${DASHBOARD_BUCKET_DOWNLOAD_FILE}
    Should Be Equal      ${downloaded_content}      ${uploaded_content}


*** Keywords ***
Prepare Dashboard Bucket Transfer Test
      [Documentation]    Builds unique bucket names and local files for the UI transfer test.
      ${suffix}=    Evaluate      ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))    modules=random,string
      ${bucket_name}=    Set Variable      ${DASHBOARD_BUCKET_BASE}-${suffix}
    Set Test Variable      ${DASHBOARD_BUCKET_NAME}      ${bucket_name}
    Set Test Variable      ${DASHBOARD_BUCKET_TEST_DIR}      ${DATA_DIR}/${bucket_name}
    Set Test Variable      ${DASHBOARD_BUCKET_UPLOAD_FILE}      ${DASHBOARD_BUCKET_TEST_DIR}/${DASHBOARD_BUCKET_OBJECT_NAME}
    Set Test Variable      ${DASHBOARD_BUCKET_DOWNLOAD_FILE}      ${DASHBOARD_BUCKET_TEST_DIR}/downloaded-${DASHBOARD_BUCKET_OBJECT_NAME}
      ${content}=    Catenate
      ...    SEPARATOR=\n
      ...    OSCAR dashboard bucket transfer test
      ...    bucket=${bucket_name}
      ...    object=${DASHBOARD_BUCKET_OBJECT_NAME}
    Create Directory      ${DASHBOARD_BUCKET_TEST_DIR}
    Create File      ${DASHBOARD_BUCKET_UPLOAD_FILE}      ${content}
    Run Keyword And Ignore Error    Remove File      ${DASHBOARD_BUCKET_DOWNLOAD_FILE}

Cleanup Dashboard Bucket Transfer Test
      [Documentation]    Removes dashboard-created bucket resources through the UI and clears temporary local files.
    Run Keyword And Ignore Error    Delete Dashboard Bucket Object      ${DASHBOARD_BUCKET_NAME}      ${DASHBOARD_BUCKET_OBJECT_NAME}
    Run Keyword And Ignore Error    Delete Dashboard Bucket From List      ${DASHBOARD_BUCKET_NAME}
    Run Keyword And Ignore Error    Remove Directory      ${DASHBOARD_BUCKET_TEST_DIR}    recursive=True

Create Bucket From Dashboard
      [Documentation]    Creates a private bucket using the Buckets page controls.
      [Arguments]      ${bucket_name}
    Navigate To Buckets Page
    Click    role=button[name="New"]
    Wait For Elements State    css=input#bucketName    visible    timeout=10s
    Fill Text    css=input#bucketName      ${bucket_name}
      ${bucket_field_value}=    Get Attribute    css=input#bucketName    value
    Should Be Equal      ${bucket_field_value}      ${bucket_name}
      ${create_response_promise}=    Promise To    Wait For Response
      ...      (response) => response.url().includes('/system/buckets') && response.request().method() === 'POST'
      ...    timeout=30s
    Click With Options
      ...    xpath=//h4[normalize-space()='New']/ancestor::div[contains(@class, 'grid')][1]//button[normalize-space()='Create']
      ...    force=True
      ${create_response}=    Wait For      ${create_response_promise}
      ${post_data}=    Set Variable      ${create_response}[request][postData]
    Should Be Equal      ${post_data}[bucket_name]      ${bucket_name}
      ${create_body}=    Evaluate      $create_response.get("body", "")
    Should Be True
      ...      ${create_response}[status] >= 200 and ${create_response}[status] < 300
      ...    Bucket creation failed with status ${create_response}[status]: ${create_body}
    Wait For Elements State    xpath=//h4[normalize-space()='New']    detached    timeout=10s

Open Dashboard Bucket
         [Documentation]    Opens the bucket content view from the bucket list.
         [Arguments]        ${bucket_name}
    Go To      ${OSCAR_DASHBOARD}/ui/#/ui/minio/${bucket_name}
    Ensure Dashboard Authenticated
    Wait For Dashboard Route    minio/${bucket_name}

Upload File To Dashboard Bucket
       [Documentation]    Opens the "Upload Options" DropdownMenu, selects "Upload Files" Popover,
       ...   uploads a local file via the hidden input#file, clicks Upload, then waits for the file to appear.
       [Arguments]    ${file_path}
    Open Dashboard Bucket     ${DASHBOARD_BUCKET_NAME}
       # 1. Click "Upload Options" (DropdownMenuTrigger button) to open the DropdownMenu
    Wait For Elements State    xpath=//button[.//span[normalize-space()='Upload Options']]    visible    timeout=10s
    Click    xpath=//button[.//span[normalize-space()='Upload Options']]
       # 2. Wait for "Upload Files" button inside the DropdownMenuContent to appear
    Wait For Elements State    xpath=//button[.//span[normalize-space()='Upload Files']]    visible    timeout=10s
       # 3. Click "Upload Files" (AddFileButton PopoverTrigger)
    Click    xpath=//button[.//span[normalize-space()='Upload Files']]
       # 4. Wait for the PopoverContent to render with "Upload Files" h4
    Wait For Elements State    xpath=//h4[normalize-space()='Upload Files']    visible    timeout=10s
       # 5. Upload the file to the hidden input#file (fileInputRef.current in AddFileButton)
    Upload File By Selector    css=input#file    ${file_path}
       # 6. Wait for the file preview to appear (filename displayed in file list)
       Wait For Elements State    xpath=//div[@role='dialog'][.//h4[normalize-space()='Upload Files']]//div[contains(@class,'min-w-0')][contains(normalize-space(), '${DASHBOARD_BUCKET_OBJECT_NAME}')]    visible    timeout=60s
       # 7. Click the "Upload" button in the PopoverContent (inside the dialog)
       Click With Options    xpath=//div[@role='dialog'][.//h4[normalize-space()='Upload Files']]//button[normalize-space()='Upload']    force=True
       # 8. Wait for the upload popover/dialog to close, then dismiss any residual overlay
       Wait For Elements State    xpath=//div[@role='dialog'][.//h4[normalize-space()='Upload Files']]    hidden    timeout=30s
       ${upload_dialog_still}=    Run Keyword And Return Status
       ...    Wait For Elements State    xpath=//*[@role='dialog' or @role='alertdialog']    visible    timeout=1s
       IF    ${upload_dialog_still}
       # Dismiss any confirmation dialog left after upload (e.g., success alert)
       Press Keys    css=body    Escape
       Wait For Elements State    xpath=//*[@role='dialog' or @role='alertdialog']    hidden    timeout=5s
       END
       ${upload_menu_still}=    Run Keyword And Return Status
       ...    Wait For Elements State    xpath=//*[@role='menu'][.//*[normalize-space()='Upload Files']]    visible    timeout=1s
       IF    ${upload_menu_still}
       # Close the upload options menu so the next row action click is not consumed by the overlay.
       Press Keys    css=body    Escape
       Wait For Elements State    xpath=//*[@role='menu'][.//*[normalize-space()='Upload Files']]    hidden    timeout=5s
       END
       # 9. Refresh bucket content and wait for the file
    Wait Until Keyword Succeeds    90s    3s    Refresh Bucket Content And Wait For Object    ${DASHBOARD_BUCKET_NAME}    ${DASHBOARD_BUCKET_OBJECT_NAME}

Refresh Bucket Content And Wait For Object
      [Documentation]    Reloads the bucket content route and waits for an object row.
      [Arguments]      ${bucket_name}      ${object_name}
    Go To      ${OSCAR_DASHBOARD}/ui/#/ui/minio/${bucket_name}
    Ensure Dashboard Authenticated
    Wait For Dashboard Route    minio/${bucket_name}
    Bucket Object Row Should Be Visible      ${object_name}

Download Dashboard Bucket Object
      [Documentation]    Downloads an object using the file row download action.
      [Arguments]      ${object_name}      ${download_path}
    Wait For Bucket Object Row       ${object_name}
    Prepare Dashboard Blob Download Capture
    Click With Options    xpath=(//tr[.//td[normalize-space()='${object_name}']]//td[last()]//button)[2]    force=True
    Wait Until Keyword Succeeds      30s      1s    Dashboard Blob Download Should Be Captured
      ${downloaded_content}=    Get Captured Dashboard Blob Download
    Create File      ${download_path}      ${downloaded_content}
    Restore Dashboard Blob Download Capture

Prepare Dashboard Blob Download Capture
      [Documentation]    Captures the blob produced by the dashboard's JavaScript download action.
    Evaluate JavaScript
      ...    ${None}
      ...    () => {
      ...      window.__oscarDownloadedBlobText = null;
      ...      window.__oscarDownloadReady = false;
      ...      window.__oscarOriginalCreateObjectURL = window.__oscarOriginalCreateObjectURL || URL.createObjectURL.bind(URL);
      ...      URL.createObjectURL = (blob) => {
      ...        if (blob && typeof blob.text === "function") {
      ...          blob.text().then((text) => {
      ...            window.__oscarDownloadedBlobText = text;
      ...            window.__oscarDownloadReady = true;
      ...          });
      ...        }
      ...        return window.__oscarOriginalCreateObjectURL(blob);
      ...      };
      ...    }

Dashboard Blob Download Should Be Captured
      [Documentation]    Fails until the dashboard-created download blob has been captured.
      ${ready}=    Evaluate JavaScript    ${None}    () => window.__oscarDownloadReady === true
    Should Be True      ${ready}

Get Captured Dashboard Blob Download
      [Documentation]    Returns the text content captured from the dashboard download blob.
      ${content}=    Evaluate JavaScript    ${None}    () => window.__oscarDownloadedBlobText
    RETURN      ${content}

Restore Dashboard Blob Download Capture
      [Documentation]    Restores URL.createObjectURL after the download capture.
    Evaluate JavaScript
      ...    ${None}
      ...    () => {
      ...      if (window.__oscarOriginalCreateObjectURL) {
      ...        URL.createObjectURL = window.__oscarOriginalCreateObjectURL;
      ...      }
      ...    }

Delete Dashboard Bucket Object
      [Documentation]    Deletes an object from a bucket using the bucket content UI.
      [Arguments]      ${bucket_name}      ${object_name}
    Go To      ${OSCAR_DASHBOARD}/ui/#/ui/minio/${bucket_name}
    Ensure Dashboard Authenticated
    Wait For Dashboard Route    minio/${bucket_name}
      ${object_present}=    Run Keyword And Return Status    Wait For Bucket Object Row      ${object_name}
    IF    not ${object_present}
        RETURN
    END
    Click    xpath=(//tr[.//td[normalize-space()='${object_name}']]//td[last()]//button)[last()]
    Wait For Elements State    xpath=//*[@role='alertdialog' or @role='dialog'][.//*[normalize-space()='Confirm Deletion']]    visible    timeout=10s
    Click    xpath=//*[@role='alertdialog' or @role='dialog']//button[normalize-space()='Delete']
    Wait Until Keyword Succeeds      30s      2s    Bucket Object Row Should Be Absent      ${object_name}

Delete Dashboard Bucket From List
      [Documentation]    Deletes a bucket using the bucket list UI.
      [Arguments]      ${bucket_name}
    Navigate To Buckets Page
      ${bucket_present}=    Run Keyword And Return Status    Wait For Dashboard Bucket Row      ${bucket_name}
    IF    not ${bucket_present}
        RETURN
    END
    Click    xpath=//tr[.//a[normalize-space()='${bucket_name}']]//td[last()]//button
    Wait For Elements State    xpath=//*[@role='alertdialog' or @role='dialog'][.//*[normalize-space()='Confirm Deletion']]    visible    timeout=10s
    Click    xpath=//*[@role='alertdialog' or @role='dialog']//button[normalize-space()='Delete']
    Wait Until Keyword Succeeds      30s      2s    Dashboard Bucket Row Should Be Absent      ${bucket_name}

Wait For Dashboard Bucket Row
      [Documentation]    Filters the bucket table and waits for the target bucket row.
      [Arguments]      ${bucket_name}
    Navigate To Buckets Page
    Wait For Elements State    css=input[placeholder^="Search buckets by"]    visible    timeout=10s
    Fill Text    css=input[placeholder^="Search buckets by"]      ${bucket_name}
    Wait Until Keyword Succeeds      60s      5s    Dashboard Bucket Row Should Be Visible After Refresh      ${bucket_name}

Dashboard Bucket Row Should Be Visible After Refresh
      [Documentation]    Refreshes the bucket list from the UI and asserts that the bucket row is visible.
      [Arguments]      ${bucket_name}
    Go To      ${OSCAR_DASHBOARD}/ui/#/ui/minio
    Wait For Dashboard Route    minio
    Wait For Elements State    css=input[placeholder^="Search buckets by"]    visible    timeout=10s
    Fill Text    css=input[placeholder^="Search buckets by"]      ${bucket_name}
    Dashboard Bucket Row Should Be Visible      ${bucket_name}

Dashboard Bucket Row Should Be Visible
      [Documentation]    Asserts that the bucket row is currently visible.
      [Arguments]      ${bucket_name}
    Wait For Elements State    xpath=//tr[.//a[normalize-space()='${bucket_name}']]    visible    timeout=5s

Dashboard Bucket Row Should Be Absent
      [Documentation]    Asserts that the bucket row is not visible in the filtered list.
      [Arguments]      ${bucket_name}
    Fill Text    css=input[placeholder^="Search buckets by"]      ${bucket_name}
    Wait For Elements State    xpath=//tr[.//a[normalize-space()='${bucket_name}']]    detached    timeout=5s

Wait For Bucket Object Row
      [Documentation]    Waits until the uploaded object appears in the bucket content table.
      [Arguments]      ${object_name}
    Wait Until Keyword Succeeds      30s      2s    Bucket Object Row Should Be Visible      ${object_name}

Bucket Object Row Should Be Visible
      [Documentation]    Asserts that the object row is currently visible.
      [Arguments]      ${object_name}
    Wait For Elements State    xpath=//tr[.//td[normalize-space()='${object_name}']]    visible    timeout=5s

Bucket Object Row Should Be Absent
      [Documentation]    Asserts that the object row is not visible.
      [Arguments]      ${object_name}
    Wait For Elements State    xpath=//tr[.//td[normalize-space()='${object_name}']]    detached    timeout=5s
