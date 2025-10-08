*** Keywords ***
Generate Random Service Name
    [Arguments]    ${base_name}    ${length}=4
    ${suffix}=    Evaluate    ''.join(random.choices(string.ascii_lowercase + string.digits, k=${length}))    modules=random,string
    ${service_name}=    Set Variable    ${base_name}-${suffix}
    RETURN    ${service_name}
