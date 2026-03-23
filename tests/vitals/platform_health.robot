*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    OperatingSystem
Library    Process

*** Test Cases ***
Robot Framework Version Is Correct
    [Tags]    vitals    smoke
    [Documentation]    Verify robotframework==6.1.1 is installed.
    ${result}=    Run Process    python    -c
    ...    import robot; print(robot.version.VERSION)
    Should Contain    ${result.stdout}    6.1
    ...    msg=Expected Robot Framework 6.1.x but got: ${result.stdout}

Kiwi TCMS Web Interface Is Reachable
    [Tags]    vitals    kiwi
    [Documentation]    Verify Kiwi TCMS web interface responds (requires KIWI_URL env var).
    ${url}=    Get Environment Variable    KIWI_URL    default=http://localhost:8080
    ${resp}=    GET    ${url}    expected_status=any    timeout=10
    Should Be True    ${resp.status_code} < 500
    ...    msg=Kiwi TCMS returned unexpected status: ${resp.status_code}

Kiwi TCMS JSON-RPC Endpoint Available
    [Tags]    vitals    kiwi
    [Documentation]    Verify the JSON-RPC endpoint accepts requests.
    ${url}=    Get Environment Variable    KIWI_URL    default=http://localhost:8080
    ${body}=    Create Dictionary    jsonrpc=2.0    method=Auth.login    id=1
    ${params}=    Create Dictionary    username=guest    password=guest
    Set To Dictionary    ${body}    params=${params}
    ${resp}=    POST    ${url}/json-rpc/    json=${body}    expected_status=any    timeout=10
    Should Be True    ${resp.status_code} < 500
    ...    msg=JSON-RPC endpoint returned: ${resp.status_code}
