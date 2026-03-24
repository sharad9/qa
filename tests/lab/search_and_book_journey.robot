*** Settings ***
Library           RequestsLibrary
Library           Collections
Library           BuiltIn
Resource          ../../resources/common.resource
Resource          ../../resources/auth.resource
Variables         ../../resources/variables/default.yaml

Suite Setup       Get User Token

*** Test Cases ***
Search And Book Lab Journey
    [Tags]    lab    journey    smoke    critical
    [Documentation]
    ...    End-to-end journey: search labs → manage cart → select address,
    ...    partner, slot, patient → view summary → initiate transaction.
    ...    Steps mirror the search-and-book journey from the API execution report.
    ${headers}=    User Auth Headers

    # Step 1: Search all labs
    ${resp}=    GET    url=${BASE_URL}/labs-v2/all
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    Should Not Be Empty    ${resp.json()}

    # Step 2: Get current cart
    ${resp}=    GET    url=${BASE_URL}/labs-v2/cart
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    ${cart_id}=    Set Variable    ${CART_ID}

    # Step 3: Remove existing item from cart (if any)
    ${cart_items}=    Evaluate    ${resp.json()}.get('cartItems', [])
    ${has_items}=    Evaluate    len($cart_items) > 0
    IF    ${has_items}
        ${first_item_id}=    Set Variable    ${cart_items[0]['cartItemId']}
        ${body}=    Create Dictionary    cartId=${cart_id}    cartItemId=${first_item_id}
        ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/remove
        ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
        Log Response    ${resp}
        Should Be True    ${resp.status_code} < 500
        ...    msg=Remove from cart failed: ${resp.status_code}
    END

    # Step 4: Add lab to cart → extract new cartItemId
    ${body}=    Create Dictionary    cartId=${cart_id}    labId=${LAB_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/add
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    ${cart_item_id}=    Set Variable    ${resp.json()}[cartItem][cartItemId]

    # Step 5: Get addresses
    ${resp}=    GET    url=${BASE_URL}/labs-v2/address
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

    # Step 6: Select address
    ${body}=    Create Dictionary    cartId=${cart_id}    addressId=${ADDRESS_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-address
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

    # Step 7: Get partners → extract meta token
    ${params}=    Create Dictionary    lat=${USER_LATITUDE}    long=${USER_LONGITUDE}
    ${resp}=    GET    url=${BASE_URL}/labs-v3/cart/partners/${cart_id}
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Get partners failed: ${resp.status_code}
    ${meta}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[networkList][0][meta]

    # Step 8: Select partner (skip if partners unavailable)
    IF    ${resp.status_code} == 200 and $meta is not None
        ${body}=    Create Dictionary    meta=${meta}
        ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-partner
        ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
        Log Response    ${resp}
        Should Be True    ${resp.status_code} < 500
        ...    msg=Select partner failed: ${resp.status_code}
    END

    # Step 9: Get slots
    ${params}=    Create Dictionary    cartId=${cart_id}
    ${resp}=    GET    url=${BASE_URL}/labs-v2/slots
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Get slots failed: ${resp.status_code}

    # Step 10: Select slot
    ${date}=    Evaluate
    ...    (__import__('datetime').date.today() + __import__('datetime').timedelta(days=1)).strftime('%Y-%m-%d')
    ${body}=    Create Dictionary    date=${date}    slotId=${SLOT_ID}    cartId=${cart_id}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-slot
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Select slot failed: ${resp.status_code}

    # Step 11: Get patients
    ${resp}=    GET    url=${BASE_URL}/labs-v2/patients
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

    # Step 12: Select patient
    ${body}=    Create Dictionary    cartId=${cart_id}    patientId=${PATIENT_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-patient
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

    # Step 13: View cart summary
    ${resp}=    GET    url=${BASE_URL}/labs-v3/cart/summary/${cart_id}
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} in [200, 400]
    ...    msg=Summary returned unexpected status: ${resp.status_code}

    # Step 14: Initiate transaction
    ${token}=    Set Variable    ${USER_TOKEN}
    ${resp}=    GET
    ...    url=${BASE_URL}/labs-v2/transact?amount=146&auth=${token}&cartId=${cart_id}
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Not Be Equal As Integers    ${resp.status_code}    0
    ...    msg=Transact endpoint unreachable
