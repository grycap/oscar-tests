*** Settings ***
Documentation       Regression for owner VO changes: rejected transitions must not persist.
Resource            ${CURDIR}/../../${AUTHENTICATION_PROCESS}
Resource            ${CURDIR}/../../resources/service.resource
Library             RequestsLibrary
Library             Collections

Suite Setup         Prepare VO Transition
Suite Teardown      Cleanup VO Transition

*** Variables ***
${SERVICE_BASE}     qa527-vo-update
${SERVICE_NAME}     ${EMPTY}
${CREATED}          ${FALSE}

*** Test Cases ***
Rejected VO Transition Must Not Mutate Service
    [Documentation]    The owner is not a member of the target configured VO; a 400 alone is insufficient.
    ${initial}=    Create Dictionary    name=${SERVICE_NAME}    vo=${OWNER_VO}
    ...    image=ubuntu:22.04    cpu=0.3    memory=256Mi    script=echo original
    ...    visibility=private
    ${body}=    Evaluate    json.dumps($initial)    modules=json
    ${created}=    POST    url=${OSCAR_ENDPOINT}/system/services    data=${body}
    ...    headers=${HEADERS}    expected_status=ANY    verify=${SSL_VERIFY}
    ${reason}=    Classify Error Response    ${created}
    Log To Console    Create response classification: ${reason}
    Should Be Equal As Integers    ${created.status_code}    201    OIDC owner service creation failed
    Set Suite Variable    ${CREATED}    ${TRUE}
    ${before}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    ...    headers=${HEADERS}    expected_status=200    verify=${SSL_VERIFY}
    ${original}=    Evaluate    json.loads($before.content)    modules=json
    Should Be Equal    ${original}[vo]    ${OWNER_VO}
    ${changed}=    Evaluate    dict($initial, vo=$DENIED_VO, script='echo forbidden')
    ${update_body}=    Evaluate    json.dumps($changed)    modules=json
    ${rejected}=    PUT    url=${OSCAR_ENDPOINT}/system/services    data=${update_body}
    ...    headers=${HEADERS}    expected_status=ANY    verify=${SSL_VERIFY}
    ${after}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
    ...    headers=${HEADERS}    expected_status=200    verify=${SSL_VERIFY}
    ${persisted}=    Evaluate    json.loads($after.content)    modules=json
    Log To Console    VO update HTTP ${rejected.status_code}; persisted target VO: ${persisted}[vo] == ${DENIED_VO}
    Should Be Equal As Integers    ${rejected.status_code}    400    Expected owner VO rejection
    Should Be Equal    ${persisted}[vo]    ${OWNER_VO}    Rejected VO transition persisted in backend
    Should Be Equal    ${persisted}[script]    ${original}[script]    Rejected VO transition changed service script

*** Keywords ***
Prepare VO Transition
    Check Valid OIDC Token
    Assign Random Service Name
    ${userinfo}=    GET    url=${USERINFO_URL}    headers=${HEADERS}    expected_status=200
    ${identity}=    Evaluate    json.loads($userinfo.content)    modules=json
    ${memberships}=    Evaluate    set($identity.get('group_membership', []))
    ${status}=    GET    url=${OSCAR_ENDPOINT}/system/status
    ...    headers=${HEADERS_OSCAR}    expected_status=200    verify=${SSL_VERIFY}
    ${configured}=    Evaluate    json.loads($status.content)['oscar']['oidc']['groups']    modules=json
    ${owned}=    Evaluate    sorted(set($configured).intersection($memberships))
    ${denied}=    Evaluate    sorted(set($configured).difference($memberships))
    Should Not Be Empty    ${owned}    Owner has no configured VO for service creation
    Should Not Be Empty    ${denied}    Owner belongs to every configured VO; cannot test nonmembership
    Set Suite Variable    ${OWNER_VO}    ${owned}[0]
    Set Suite Variable    ${DENIED_VO}    ${denied}[0]
    Log To Console    Confirmed owner membership in source VO and nonmembership in target configured VO

Cleanup VO Transition
    IF    ${CREATED}
        ${deleted}=    DELETE    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
        ...    headers=${HEADERS}    expected_status=ANY    verify=${SSL_VERIFY}
        Should Be Equal As Integers    ${deleted.status_code}    204    Test service deletion failed
        ${after}=    GET    url=${OSCAR_ENDPOINT}/system/services/${SERVICE_NAME}
        ...    headers=${HEADERS}    expected_status=ANY    verify=${SSL_VERIFY}
        Should Be Equal As Integers    ${after.status_code}    404    Test service remains after deletion
        Log To Console    Test-owned service deleted and absent on read-back
    END
