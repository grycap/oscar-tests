*** Settings ***
Documentation    Tests for the OSCAR's UI endpoint.

Library          Browser


*** Variables *** 
${OSCAR_DASHBOARD}=        %{OSCAR_DASHBOARD}


*** Test Cases ***
Open OSCAR Dashboard Page
    New Page    url= ${OSCAR_DASHBOARD}
    ${title}=    Get Title
    Should Be Equal As Strings    ${title}    OSCAR
    Close Browser