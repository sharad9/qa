*** Settings ***
Library           RequestsLibrary
Library           Collections
Resource          ../../resources/common.resource
Resource          ../../resources/auth.resource
Variables         ../../resources/variables/default.yaml

Suite Setup       Get User Token

*** Test Cases ***
Search All Labs Returns List
    [Tags]    lab    smoke    critical
    [Documentation]    GET /labs-v2/all returns 200 and a non-empty list of labs.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/all    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    Should Not Be Empty    ${resp.json()}

Get Cart Returns Cart Data
    [Tags]    lab    smoke
    [Documentation]    GET /labs-v2/cart returns 200.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/cart    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Get Addresses Returns List
    [Tags]    lab    smoke
    [Documentation]    GET /labs-v2/address returns 200 and saved addresses.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/address    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Get Partners For Cart
    [Tags]    lab    regression
    [Documentation]    GET /labs-v3/cart/partners/:cartId returns available partners.
    ${headers}=    User Auth Headers
    ${params}=    Create Dictionary    lat=28.5681199    long=77.31620029999999
    ${resp}=    GET    url=${BASE_URL}/labs-v3/cart/partners/${CART_ID}
    ...    headers=${headers}    params=${params}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Get Slots For Cart
    [Tags]    lab    regression
    [Documentation]    GET /labs-v2/slots?cartId= returns available time slots.
    ${headers}=    User Auth Headers
    ${params}=    Create Dictionary    cartId=${CART_ID}
    ${resp}=    GET    url=${BASE_URL}/labs-v2/slots
    ...    headers=${headers}    params=${params}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Get Patients Returns List
    [Tags]    lab    regression
    [Documentation]    GET /labs-v2/patients returns the user's patient profiles.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/patients    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Get Cart Summary
    [Tags]    lab    regression
    [Documentation]    GET /labs-v3/cart/summary/:cartId returns order summary (200 or 400 for expired cart).
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v3/cart/summary/${CART_ID}    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} in [200, 400]
    ...    msg=Expected HTTP 200 or 400 but got ${resp.status_code}: ${resp.text}
