*** Settings ***
Library    RequestsLibrary
Library    Collections
Variables  variables/default.yaml

*** Variables ***
${ACCESS_TOKEN}    ${EMPTY}

*** Keywords ***
Register API Client
    [Documentation]    Register a new API client.
    ...                The Simple Books API requires unique email per client.
    ${body}=    Create Dictionary
    ...    clientName=${CLIENT_NAME}
    ...    clientEmail=${CLIENT_EMAIL}
    ${resp}=    POST    ${BASE_URL}/api-clients/    json=${body}    expected_status=any
    Log    Status: ${resp.status_code}
    Log    Body: ${resp.text}
    # 409 = client already exists — that's fine
    Run Keyword Unless    ${resp.status_code} in [201, 409]
    ...    Fail    Client registration failed: ${resp.text}

Get Access Token
    [Documentation]    Register client and obtain a Bearer access token.
    ...                On first call returns 201 + accessToken. On duplicate email returns 409.
    ...                Use a timestamp-suffixed CLIENT_EMAIL to ensure fresh token every run.
    ${body}=    Create Dictionary    clientName=${CLIENT_NAME}    clientEmail=${CLIENT_EMAIL}
    ${resp}=    POST    ${BASE_URL}/api-clients/    json=${body}    expected_status=any
    Log    Status: ${resp.status_code}
    Log    Body: ${resp.text}
    Run Keyword If    ${resp.status_code} != 201
    ...    Fail    Expected 201 from /api-clients/ but got ${resp.status_code}. Use a unique CLIENT_EMAIL.
    ${token}=    Set Variable    ${resp.json()}[accessToken]
    Set Suite Variable    ${ACCESS_TOKEN}    ${token}
    [Return]    ${token}
