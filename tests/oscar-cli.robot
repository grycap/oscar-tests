*** Comments *** 

Tests for the OSCAR CLI against a deployed OSCAR cluster


*** Settings ***

Library    Process
Library    OperatingSystem
Resource    ../resources/resources.robot


*** Keywords ***

Remove files from tests and verify
    [Arguments]    ${file}
    Remove File    ${file}
    File Should Not Exist    ${file}

Get job name from logs
    ${job_name}=    Run Process    oscar-cli    service    logs    list    robot-test-cowsay    |    awk    'NR    \=\=    2    {print    $1}'    shell=True    stdout=True    stderr=True
    Set Suite Variable    ${job_name}    ${job_name.stdout}
    RETURN    ${job_name}


*** Test Cases ***

OSCAR CLI installed
    [Documentation]    Check that OSCAR CLI is installed
    ${result}=    Run Process    oscar-cli        stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    # Should Contain    ${result.stdout}    apply

OSCAR CLI cluster add
    [Documentation]    Check that OSCAR CLI adds a cluster
    ${result}=    Run Process    oscar-cli    cluster    add    robot-oscar-cluster    ${OSCAR_ENDPOINT}    --oidc-account-name  ${OIDC_AGENT_ACCOUNT}    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    successfully

OSCAR CLI cluster default
    [Documentation]    Check that OSCAR CLI sets a cluster as default
    ${result}=    Run Process    oscar-cli    cluster    default    --set    robot-oscar-cluster    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    successfully

OSCAR CLI cluster info
    [Documentation]    Check that OSCAR CLI shows info about the default cluster
    ${result}=    Run Process    oscar-cli    cluster    info    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0
    # Should Contain    ${result.stdout}    kubernetes_version

OSCAR CLI cluster list
    [Documentation]    Check that OSCAR CLI lists clusters
    ${result}=    Run Process    oscar-cli    cluster    list    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Contain    ${result.stdout}    robot-oscar-cluster

OSCAR CLI apply
    [Documentation]    Check that OSCAR CLI creates a service in the default cluster
    ${result}=    Run Process    oscar-cli    apply    ./data/00-cowsay.yaml    stdout=True    stderr=True
    Sleep    30s
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI list services 
    [Documentation]    Check that OSCAR CLI returns a list of services from the default cluster
    ${result}=    Run Process    oscar-cli    service    list    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    robot-test-cowsay

# OSCAR CLI run services synchronously
#     [Documentation]    Check that OSCAR CLI runs a service synchronously in the default cluster
#     ${result}=    Run Process    oscar-cli    service    run    robot-test-cowsay    --input    ./data/00-cowsay-invoke-body.json    stdout=True    stderr=True
#     Log    ${result.stdout}
#     # Should Be Equal As Integers    ${result.rc}    0
#     Should Contain    ${result.stdout}    Hello

OSCAR CLI run services synchronously
    [Documentation]    Check that OSCAR CLI runs a service synchronously in the default cluster
    ${result}=    Run Process    oscar-cli    service    run    robot-test-cowsay    --text-input    {"message": "Hello there from AI4EOSC"}    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    Hello

OSCAR CLI put file 
    [Documentation]    Check that OSCAR CLI puts a file in a service's storage provider
    ${result}=    Run Process    oscar-cli    service    put-file    robot-test-cowsay    minio.default    ./data/00-cowsay-invoke-body.json    robot-test/input/00-cowsay-invoke-body.json    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI list files
    [Documentation]    Check that OSCAR CLI lists files from a service's storage provider path
    ${result}=    Run Process    oscar-cli    service    list-files    robot-test-cowsay    minio.default    robot-test/input/    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    00-cowsay-invoke-body.json

OSCAR CLI logs list 
    [Documentation]    Check that OSCAR CLI lists the logs for a service
    ${result}=    Run Process    oscar-cli    service    logs    list    robot-test-cowsay    stdout=True    stderr=True
    Sleep    15s
    Log    ${result.stdout}
    ${job_name}=    Get job name from logs
    Log    ${job_name}
    Should Be Equal As Integers    ${result.rc}    0
    # Should Contain    ${result.stdout}    robot-test-cowsay-

OSCAR CLI logs get
    [Documentation]    Check that OSCAR CLI gets the logs from a service's job
    ${result}=    Run Process    oscar-cli    service    logs    get    robot-test-cowsay    ${job_name}    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    Hello

OSCAR CLI logs remove
    [Documentation]    Check that OSCAR CLI removes the logs from a service's job
    ${result}=    Run Process    oscar-cli    service    logs    remove    robot-test-cowsay    ${job_name}    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    successfully

OSCAR CLI get file
    [Documentation]    Check that OSCAR CLI gets a file from a service's storage provider
    ${result}=    Run Process    oscar-cli    service    get-file    robot-test-cowsay    minio.default    robot-test/input/00-cowsay-invoke-body.json    00-cowsay-invoke-body-downloaded.json    stdout=True    stderr=True
    Log    ${result.stdout}
    # Should Be Equal As Integers    ${result.rc}    0
    File Should Exist    00-cowsay-invoke-body-downloaded.json

OSCAR CLI remove services
    [Documentation]    Check that OSCAR CLI removes a service
    ${result}=    Run Process    oscar-cli    service    remove    robot-test-cowsay    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

OSCAR CLI cluster remove
    [Documentation]    Check that OSCAR CLI removes a cluster
    ${result}=    Run Process    oscar-cli    cluster    remove    robot-oscar-cluster    stdout=True    stderr=True
    Log    ${result.stdout}
    Should Be Equal As Integers    ${result.rc}    0

Remove files from tests
    [Documentation]    Remove junk files created during the tests
    Remove files from tests and verify    00-cowsay-invoke-body-downloaded.json
    Remove files from tests and verify    True
