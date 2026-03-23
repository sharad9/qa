*** Settings ***
Library           RequestsLibrary
Library           Collections
Resource          ../../resources/common.resource
Variables         ../../resources/variables/default.yaml

Suite Setup       Run Keywords    Verify API Is Up    AND    Initialize Auth

*** Variables ***
${TOKEN}          ${EMPTY}
${ORDER_ID}       ${EMPTY}

*** Keywords ***
Initialize Auth
    [Documentation]    Obtain a fresh access token for this suite run.
    ${ts}=    Evaluate    int(__import__('time').time())
    ${email}=    Set Variable    orders+${ts}@bookstore-sample.test
    ${body}=    Create Dictionary    clientName=BookstoreQA    clientEmail=${email}
    ${resp}=    POST    ${BASE_URL}/api-clients/    json=${body}    expected_status=201
    Set Suite Variable    ${TOKEN}    ${resp.json()}[accessToken]

Auth Headers
    [Documentation]    Return a dict with the Authorization header.
    ${headers}=    Create Dictionary    Authorization=Bearer ${TOKEN}
    [Return]    ${headers}

*** Test Cases ***
Place An Order
    [Tags]    orders    smoke    critical
    [Documentation]    POST /orders with a valid bookId places an order and returns 201.
    ${headers}=    Auth Headers
    ${body}=    Create Dictionary    bookId=${1}    customerName=QA Tester
    ${resp}=    POST    ${BASE_URL}/orders    json=${body}    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    201
    Dictionary Should Contain Key    ${resp.json()}    orderId
    Set Suite Variable    ${ORDER_ID}    ${resp.json()}[orderId]

Get Placed Order
    [Tags]    orders    smoke
    [Documentation]    GET /orders/:id returns the order just placed.
    [Setup]    Run Keyword If    '${ORDER_ID}' == '${EMPTY}'    Skip    Place An Order must run first
    ${headers}=    Auth Headers
    ${resp}=    GET    ${BASE_URL}/orders/${ORDER_ID}    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    Should Be Equal    ${resp.json()}[id]    ${ORDER_ID}

List Orders Returns Array
    [Tags]    orders    regression
    [Documentation]    GET /orders returns a JSON array for this client.
    ${headers}=    Auth Headers
    ${resp}=    GET    ${BASE_URL}/orders    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    ${orders}=    Set Variable    ${resp.json()}
    Should Be True    isinstance($orders, list)

Update Order Customer Name
    [Tags]    orders    regression
    [Documentation]    PATCH /orders/:id updates the customerName field.
    [Setup]    Run Keyword If    '${ORDER_ID}' == '${EMPTY}'    Skip    Place An Order must run first
    ${headers}=    Auth Headers
    ${body}=    Create Dictionary    customerName=Updated QA Tester
    ${resp}=    PATCH    ${BASE_URL}/orders/${ORDER_ID}    json=${body}    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    204

Delete Order
    [Tags]    orders    regression
    [Documentation]    DELETE /orders/:id removes the order; subsequent GET returns 404.
    [Setup]    Run Keyword If    '${ORDER_ID}' == '${EMPTY}'    Skip    Place An Order must run first
    ${headers}=    Auth Headers
    ${resp}=    DELETE    ${BASE_URL}/orders/${ORDER_ID}    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    204
    # Confirm deletion
    ${check}=    GET    ${BASE_URL}/orders/${ORDER_ID}    headers=${headers}    expected_status=any
    Verify Status Code    ${check}    404
