*** Settings ***
Documentation       Shared parsing helpers for OSCAR kind deployment output.
Library             Collections
Library             String


*** Keywords ***
Parse Deployment Details
    [Documentation]    Extracts the relevant values from the deploy script output.
    [Arguments]    ${stdout}
    ${cluster}=         Extract Deployment Detail    ${stdout}    Kind cluster name:\\s*(.+)
    ${context}=         Extract Deployment Detail    ${stdout}    Kind context:\\s*(.+)
    ${http_line}=       Extract Deployment Detail    ${stdout}    OSCAR HTTP port:\\s*(.+)
    ${https_line}=      Extract Deployment Detail    ${stdout}    OSCAR HTTPS port:\\s*(.+)
    ${http_url}=        Replace String Using Regexp    ${http_line}    .*?\\(([^)]+)\\).*    \\1
    ${http_url}=        Strip String    ${http_url}
    ${https_url}=       Replace String Using Regexp    ${https_line}    .*?\\(([^)]+)\\).*    \\1
    ${https_url}=       Strip String    ${https_url}
    ${cred_line}=       Extract Deployment Detail   ${stdout}        OSCAR credentials:\\s*(.+)
    ${username}=        Replace String Using Regexp    ${cred_line}    .*username='([^']+)'.*    \\1
    ${username}=        Strip String    ${username}
    ${password}=        Replace String Using Regexp    ${cred_line}    .*password='([^']+)'.*    \\1
    ${password}=        Strip String    ${password}
    ${basic_token}=     Compute Basic Token    ${username}    ${password}
    ${details}=         Create Dictionary    cluster_name=${cluster}    context=${context}
    ...                 http_url=${http_url}    https_url=${https_url}
    ...                 basic_token=${basic_token}    username=${username}    password=${password}
    RETURN    ${details}

Compute Basic Token
    [Documentation]    Builds the base64 encoded username:password pair expected by OSCAR.
    [Arguments]    ${username}    ${password}
    ${plain}=    Catenate    SEPARATOR=:    ${username}    ${password}
    ${token}=    Call Base64 Encode    ${plain}
    RETURN    ${token}

Call Base64 Encode
    [Documentation]    Wrapper around Python's base64 encoder to avoid literal escaping issues.
    [Arguments]    ${value}
    ${token}=    Evaluate    __import__('base64').b64encode(\"\"\"${value}\"\"\".encode()).decode()
    RETURN    ${token}

Extract Deployment Detail
    [Documentation]    Returns the first match for the given multiline pattern.
    [Arguments]    ${text}    ${pattern}
    ${matches}=    Get Regexp Matches    ${text}    (?m)${pattern}    1
    ${count}=      Get Length    ${matches}
    IF    ${count} == 0
        Fail    Could not find pattern '${pattern}' in deploy output.
    END
    ${value}=      Get From List    ${matches}    0
    ${value}=      Strip String    ${value}
    RETURN    ${value}
