*** Comments *** 
Tests for the OSCAR's UI endpoints. Work in progress. Not functional.

*** Settings ***

Library    Browser

Suite Setup     New Browser    firefox    headless=True

*** Variables *** 

${OSCAR_ENDPOINT}=    %{oscar_endpoint}
${OSCAR_USERNAME}=    %{oscar_username}
${OSCAR_PASSWORD}=    %{oscar_password}


*** Test Cases ***

As a user, I can log into the OSCAR dashboard so that I can browse services
    [Setup]    New Context    baseURL=${OSCAR_ENDPOINT}
    Given We are at the OSCAR Dashboard Login page
    

*** Keywords *** 

We are at the OSCAR Dashboard Login page
    New Page    url=${OSCAR_ENDPOINT}
    Go to    url=${OSCAR_ENDPOINT}
    Get Url    should be    ${OSCAR_ENDPOINT}/ui/#/login
