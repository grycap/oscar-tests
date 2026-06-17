*** Settings ***
Documentation       Tests for the OSCAR CLI bucket commands (CRUD and visibility transitions).

Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS} 
Resource            ${CURDIR}/../../resources/files.resource
Resource            ${CURDIR}/../../resources/service.resource
Library             Process

Suite Setup         Setup Bucket CLI Suite
Suite Teardown      Teardown Bucket CLI Suite

*** Variables ***
${CLUSTER_NAME}     robot-cli-bucket
${BUCKET_BASE}      robot-cli-bkt

*** Test Cases ***
OSCAR CLI Installed
    [Documentation]    Check that OSCAR CLI is installed
    ${result}=    Run Process    oscar-cli    stdout=True    stderr=True
    Should Be Equal As Integers    ${result.rc}    0


OSCAR CLI Bucket Create Private
    [Documentation]    Create a private bucket
    ${result}=    Run Process    oscar-cli    bucket    create    ${BUCKET_NAME}
    ...    --visibility    private    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Bucket List Shows Private
    [Documentation]    Verify the bucket appears with private visibility
    ${result}=    Run Process    oscar-cli    bucket    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${BUCKET_NAME}
    Should Contain    ${result.stdout}    private

OSCAR CLI Bucket Update Private To Public
    [Documentation]    Update bucket visibility from private to public
    Log    ${BUCKET_NAME}     console=yes
    ${result}=    Run Process    oscar-cli    bucket    update    ${BUCKET_NAME}
    ...    --visibility    public    stdout=True    stderr=True
    Log    ${result.stdout}     console=yes
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Bucket List Shows Public
    [Documentation]    Verify the bucket now has public visibility
    ${result}=    Run Process    oscar-cli    bucket    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${BUCKET_NAME}
    Should Contain    ${result.stdout}    public

OSCAR CLI Bucket Update Public To Private
    [Documentation]    Update bucket visibility from public back to private
    ${result}=    Run Process    oscar-cli    bucket    update    ${BUCKET_NAME}
    ...    --visibility    private    stdout=True    stderr=True
    Log    ${result.stdout}     console=yes
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Bucket List Shows Private Again
    [Documentation]    Verify the bucket is private again
    ${result}=    Run Process    oscar-cli    bucket    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${BUCKET_NAME}
    Should Contain    ${result.stdout}    private

OSCAR CLI Bucket Delete Private
    [Documentation]    Delete the private bucket
    ${result}=    Run Process    oscar-cli    bucket    delete    ${BUCKET_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Bucket Create Restricted
    [Documentation]    Create a restricted bucket
    ${result}=    Run Process    oscar-cli    bucket    create    ${BUCKET_NAME}
    ...    --visibility    restricted       --allowed-users     ${OTHER_USER}    stdout=True    stderr=True
    Log    ${result.stdout} 
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Bucket List Shows Restricted
    [Documentation]    Verify the restricted bucket appears in the list
    ${result}=    Run Process    oscar-cli    bucket    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${BUCKET_NAME}
    Should Contain    ${result.stdout}    restricted

OSCAR CLI Bucket Delete Restricted
    [Documentation]    Delete the restricted bucket
    ${result}=    Run Process    oscar-cli    bucket    delete    ${BUCKET_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Bucket Create Public
    [Documentation]    Create a public bucket
    ${result}=    Run Process    oscar-cli    bucket    create    ${BUCKET_NAME}
    ...    --visibility    public    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Bucket List Shows Public Creation
    [Documentation]    Verify the public bucket appears in the list
    ${result}=    Run Process    oscar-cli    bucket    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    ${BUCKET_NAME}
    Should Contain    ${result.stdout}    public

OSCAR CLI Bucket Delete Public
    [Documentation]    Delete the public bucket
    ${result}=    Run Process    oscar-cli    bucket    delete    ${BUCKET_NAME}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI Bucket List After All Deletions
    [Documentation]    Verify the bucket no longer appears in the list
    ${result}=    Run Process    oscar-cli    bucket    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    Should Not Contain    ${result.stdout}    ${BUCKET_NAME}

*** Keywords ***
Setup Bucket CLI Suite
    [Documentation]    Set up OIDC token, add cluster, and generate random bucket name
    Set Refresh Token
    Checks Valids OIDC Token
    ${result}=    Run Process    oscar-cli    cluster    add    ${CLUSTER_NAME}    ${OSCAR_ENDPOINT}
    ...    --oidc-refresh-token    ${REFRESH_TOKEN}    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Contain    ${result.stdout}    successfully
    ${result}=    Run Process    oscar-cli    cluster    default    --set    ${CLUSTER_NAME}
    ...    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Contain    ${result.stdout}    successfully
    ${bucket_name}=    Generate Random Service Name    ${BUCKET_BASE}
    Set Suite Variable    ${BUCKET_NAME}    ${bucket_name}

Teardown Bucket CLI Suite
    [Documentation]    Clean up bucket and cluster
    Run Keyword And Ignore Error    Run Process    oscar-cli    bucket    delete    ${BUCKET_NAME}
    ...    stdout=True    stderr=True
    Run Keyword And Ignore Error    Run Process    oscar-cli    cluster    remove    ${CLUSTER_NAME}
    ...    stdout=True    stderr=True
