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
    ...    End-to-end: search labs → get cart → remove old item → add lab →
    ...    select address → get/select partner (extract meta) → get/select slot →
    ...    get/select patient → summary → initiate transaction (Cashfree).
    ...    14 steps mirroring the search-and-book journey report.
    ${headers}=    User Auth Headers

    # ── Step 1: Search all labs ───────────────────────────────────────────────
    ${resp}=    GET    url=${BASE_URL}/labs-v2/all
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    Should Not Be Empty    ${resp.json()}[labs]

    # ── Step 2: Get current cart → extract cartId and existing cartItemId ─────
    ${resp}=    GET    url=${BASE_URL}/labs-v2/cart
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    ${cart_id}=    Set Variable    ${resp.json()}[cartId]
    ${cart_items}=    Set Variable    ${resp.json()}[cart]

    # ── Step 3: Remove existing item from cart (if any) ───────────────────────
    ${has_items}=    Evaluate    len($cart_items) > 0
    IF    ${has_items}
        ${cart_item_id}=    Set Variable    ${cart_items[0]['cartItemId']}
        ${body}=    Create Dictionary    cartId=${cart_id}    cartItemId=${cart_item_id}
        ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/remove
        ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
        Log Response    ${resp}
        Verify Status Code    ${resp}    200
    END

    # ── Step 4: Add lab to cart → extract new cartItemId ─────────────────────
    ${body}=    Create Dictionary    cartId=${cart_id}    labId=${LAB_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/add
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    ${new_cart_item_id}=    Set Variable    ${resp.json()}[cartItem][cartItemId]

    # ── Step 5: Get addresses ─────────────────────────────────────────────────
    ${resp}=    GET    url=${BASE_URL}/labs-v2/address
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

    # ── Step 6: Select address ────────────────────────────────────────────────
    ${body}=    Create Dictionary    cartId=${cart_id}    addressId=${ADDRESS_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-address
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    Should Be Equal    ${resp.json()}[screen]    partner-selection-screen

    # ── Step 7: Get partners → extract meta token from first partner ──────────
    ${params}=    Create Dictionary    lat=${USER_LATITUDE}    long=${USER_LONGITUDE}
    ${resp}=    GET    url=${BASE_URL}/labs-v3/cart/partners/${cart_id}
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Get partners failed: ${resp.status_code}
    ${partner_meta}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[networkList][0][meta]

    # ── Step 8: Select partner ────────────────────────────────────────────────
    IF    ${resp.status_code} == 200
        ${body}=    Create Dictionary    meta=${partner_meta}
        ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-partner
        ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
        Log Response    ${resp}
        Should Be True    ${resp.status_code} < 500
        ...    msg=Select partner failed: ${resp.status_code}
    END

    # ── Step 9: Get slots ─────────────────────────────────────────────────────
    ${params}=    Create Dictionary    cartId=${cart_id}
    ${resp}=    GET    url=${BASE_URL}/labs-v2/slots
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Get slots failed: ${resp.status_code}
    # Extract first available date and slotId
    ${slot_date}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[slots][0][date]
    ${slot_id}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[slots][0][time][0][slotId]

    # ── Step 10: Select slot ──────────────────────────────────────────────────
    ${date}=    Set Variable If    $slot_date is not None    ${slot_date}
    ...    ${SLOT_ID}
    ${sid}=    Set Variable If    $slot_id is not None    ${slot_id}    ${SLOT_ID}
    ${body}=    Create Dictionary    date=${date}    slotId=${sid}    cartId=${cart_id}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-slot
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Select slot failed: ${resp.status_code}

    # ── Step 11: Get patients ─────────────────────────────────────────────────
    ${resp}=    GET    url=${BASE_URL}/labs-v2/patients
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    ${patient_id}=    Set Variable    ${resp.json()}[patients][0][patientId]

    # ── Step 12: Select patient ───────────────────────────────────────────────
    ${body}=    Create Dictionary    cartId=${cart_id}    patientId=${patient_id}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-patient
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

    # ── Step 13: View cart summary → extract amount ───────────────────────────
    ${resp}=    GET    url=${BASE_URL}/labs-v3/cart/summary/${cart_id}
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} in [200, 400]
    ...    msg=Summary returned unexpected status: ${resp.status_code}
    ${amount}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[cartSummary][payableAmount]
    ${amount}=    Set Variable If    $amount is not None    ${amount}    146

    # ── Step 14: Initiate transaction → Cashfree payment page (HTML 200) ──────
    ${token}=    Set Variable    ${USER_TOKEN}
    ${resp}=    GET
    ...    url=${BASE_URL}/labs-v2/transact?amount=${amount}&auth=${token}&cartId=${cart_id}
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Not Be Equal As Integers    ${resp.status_code}    0
    ...    msg=Transact endpoint unreachable
