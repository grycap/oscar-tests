*** Keywords ***
Assign Random Service Name
    ${service_name}=    Generate Random Service Name    ${SERVICE_BASE}
    Set Suite Variable    ${SERVICE_NAME}    ${service_name}
    Set Suite Variable    ${BUCKET_NAME}    ${service_name}

Assign Random String
    ${random_string}=    Evaluate    ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))    modules=random,string
    Set Suite Variable    ${RANDOM_STRING}    ${random_string}

Generate Random Service Name
    [Arguments]    ${base_name}    ${length}=1
    ${base_length}=    Get Length    ${base_name}
    ${max_suffix_length}=    Evaluate    max(1, 20 - ${base_length} - 1)
    ${suffix}=    Evaluate    ''.join(random.choices(string.ascii_lowercase + string.digits, k=${max_suffix_length}))    modules=random,string
    ${service_name}=    Set Variable    ${base_name}-${suffix}
    RETURN    ${service_name}

Classify Error Response
    [Documentation]    Diagnostic logging sanitizer: returns up to 180 chars of the response body
    ...    only when the request was rejected with 400 and the text contains no secrets
    ...    (token/password, case-insensitive); otherwise returns 'redacted' to keep
    ...    credentials out of CI logs.
    [Arguments]    ${response}
    ${has_secret}=    Evaluate    'token' in $response.text.lower() or 'password' in $response.text.lower()
    IF    $has_secret
        RETURN    redacted
    ELSE IF    $response.status_code == 400
        RETURN    $response.text[:180]
    ELSE
        RETURN    redacted
    END

Build Exposed Service URL
    [Documentation]    Build the root DNS URL for an exposed service, preserving endpoint scheme and port.
    [Arguments]    ${service_name}    ${path}=${EMPTY}
    ${url}=    Evaluate
    ...    (lambda u: urllib.parse.urljoin(u._replace(netloc=f"{service_name}.{u.hostname}" + (f":{u.port}" if u.port else ""), path="/", query="", fragment="").geturl(), path.lstrip("/")))(urllib.parse.urlsplit(endpoint))
    ...    modules=urllib.parse
    ...    namespace=${{ {"endpoint": $OSCAR_ENDPOINT, "service_name": $service_name, "path": $path} }}
    RETURN    ${url}
