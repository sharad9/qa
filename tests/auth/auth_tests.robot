*** Settings ***
Library           RequestsLibrary
Library           Collections
Resource          ../../resources/common.resource
Variables         ../../resources/variables/default.yaml

Suite Setup       Verify API Is Up

*** Test Cases ***
Register New Client Returns Access Token
    [Tags]    auth    smoke    critical
    [Documentation]    POST /api-clients/ with a unique email returns 201 and an accessToken.
    ${ts}=    Evaluate    int(__import__('time').time())
    ${email}=    Set Variable    qa+${ts}@bookstore-sample.test
    ${body}=    Create Dictionary    clientName=BookstoreQA    clientEmail=${email}
    ${resp}=    POST    ${BASE_URL}/api-clients/    json=${body}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    201
    Dictionary Should Contain Key    ${resp.json()}    accessToken
    Should Not Be Empty    ${resp.json()}[accessToken]

Duplicate Client Registration Returns 409
    [Tags]    auth    regression
    [Documentation]    Registering the same email twice returns 409 Conflict.
    ${ts}=    Evaluate    int(__import__('time').time())
    ${email}=    Set Variable    qa+dup${ts}@bookstore-sample.test
    ${body}=    Create Dictionary    clientName=BookstoreQA    clientEmail=${email}
    POST    ${BASE_URL}/api-clients/    json=${body}    expected_status=201
    ${resp}=    POST    ${BASE_URL}/api-clients/    json=${body}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    409

Protected Endpoint Requires Token
    [Tags]    auth    smoke    critical
    [Documentation]    GET /orders without Authorization header returns 401.
    ${resp}=    GET    ${BASE_URL}/orders    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    401
