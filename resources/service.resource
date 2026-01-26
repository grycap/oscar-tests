*** Keywords ***
Assign Random Service Name
    ${service_name}=    Generate Random Service Name    ${SERVICE_BASE}
    Set Suite Variable    ${SERVICE_NAME}    ${service_name}

Assign Random String
    ${random_string}=    Evaluate    ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))    modules=random,string
    Set Suite Variable    ${RANDOM_STRING}    ${random_string}

Generate Random Service Name
    [Arguments]    ${base_name}    ${length}=4
    ${suffix}=    Evaluate    ''.join(random.choices(string.ascii_lowercase + string.digits, k=${length}))    modules=random,string
    ${service_name}=    Set Variable    ${base_name}-${suffix}
    RETURN    ${service_name}