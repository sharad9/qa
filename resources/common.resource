*** Settings ***
Library    RequestsLibrary
Library    Collections

*** Keywords ***
Verify API Is Up
    [Documentation]    Ping the API status endpoint. Skip entire suite if unreachable.
    ${resp}=    GET    ${BASE_URL}/status    expected_status=any    timeout=${TIMEOUT}
    Run Keyword If    ${resp.status_code} >= 500
    ...    Skip    API unreachable (status ${resp.status_code}) — skipping suite

Log Response
    [Arguments]    ${resp}
    Log    Status: ${resp.status_code}
    Log    Body: ${resp.text}

Verify Status Code
    [Arguments]    ${resp}    ${expected}
    Should Be Equal As Integers    ${resp.status_code}    ${expected}
    ...    msg=Expected HTTP ${expected} but got ${resp.status_code}: ${resp.text}
