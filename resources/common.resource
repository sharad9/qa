*** Settings ***
Library    RequestsLibrary
Library    Collections

*** Keywords ***
Log Response
    [Arguments]    ${resp}
    Log    Status: ${resp.status_code}
    Log    Body: ${resp.text}

Verify Status Code
    [Arguments]    ${resp}    ${expected}
    Should Be Equal As Integers    ${resp.status_code}    ${expected}
    ...    msg=Expected HTTP ${expected} but got ${resp.status_code}: ${resp.text}
