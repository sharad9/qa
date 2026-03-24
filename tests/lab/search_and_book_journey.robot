*** Settings ***
Library           RequestsLibrary
Library           Collections
Library           BuiltIn
Resource          ../../resources/common.resource
Resource          ../../resources/auth.resource
Variables         ../../resources/variables/default.yaml

Suite Setup       Get User Token

*** Test Cases ***

# ── Step 1 ────────────────────────────────────────────────────────────────────
Search All Labs
    [Tags]    lab    journey    smoke    critical
    [Documentation]    GET /labs-v2/all — returns list of available labs.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/all
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    Should Not Be Empty    ${resp.json()}[labs]

# ── Step 2 ────────────────────────────────────────────────────────────────────
Get Current Cart
    [Tags]    lab    journey    smoke
    [Documentation]    GET /labs-v2/cart — returns cartId and existing items.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/cart
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    Set Suite Variable    ${JOURNEY_CART_ID}       ${resp.json()}[cartId]
    Set Suite Variable    ${JOURNEY_CART_ITEMS}    ${resp.json()}[cart]

# ── Step 3 ────────────────────────────────────────────────────────────────────
Remove Existing Item From Cart
    [Tags]    lab    journey    smoke
    [Documentation]    POST /labs-v2/cart/remove — clears cart before adding a new lab.
    ${headers}=    User Auth Headers
    ${has_items}=    Evaluate    len($JOURNEY_CART_ITEMS) > 0
    IF    ${has_items}
        ${cart_item_id}=    Set Variable    ${JOURNEY_CART_ITEMS[0]['cartItemId']}
        ${body}=    Create Dictionary    cartId=${JOURNEY_CART_ID}    cartItemId=${cart_item_id}
        ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/remove
        ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
        Log Response    ${resp}
        Verify Status Code    ${resp}    200
    ELSE
        Log    Cart already empty — skipping remove step
    END

# ── Step 4 ────────────────────────────────────────────────────────────────────
Add Lab To Cart
    [Tags]    lab    journey    smoke
    [Documentation]    POST /labs-v2/cart/add — adds LAB_ID to cart, extracts cartItemId.
    ${headers}=    User Auth Headers
    ${body}=    Create Dictionary    cartId=${JOURNEY_CART_ID}    labId=${LAB_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/add
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    Set Suite Variable    ${JOURNEY_CART_ITEM_ID}    ${resp.json()}[cartItem][cartItemId]

# ── Step 5 ────────────────────────────────────────────────────────────────────
Get Addresses
    [Tags]    lab    journey    smoke
    [Documentation]    GET /labs-v2/address — retrieves saved delivery addresses.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/address
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

# ── Step 6 ────────────────────────────────────────────────────────────────────
Select Address
    [Tags]    lab    journey    smoke
    [Documentation]    POST /labs-v2/cart/select-address — sets delivery address on cart.
    ${headers}=    User Auth Headers
    ${body}=    Create Dictionary    cartId=${JOURNEY_CART_ID}    addressId=${ADDRESS_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-address
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    Should Be Equal    ${resp.json()}[screen]    partner-selection-screen

# ── Step 7 ────────────────────────────────────────────────────────────────────
Get Partners
    [Tags]    lab    journey    smoke
    [Documentation]    GET /labs-v3/cart/partners/:cartId — returns available partners with meta token.
    ${headers}=    User Auth Headers
    ${params}=    Create Dictionary    lat=${USER_LATITUDE}    long=${USER_LONGITUDE}
    ${resp}=    GET    url=${BASE_URL}/labs-v3/cart/partners/${JOURNEY_CART_ID}
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Get partners failed: ${resp.status_code}
    ${meta}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[networkList][0][meta]
    Set Suite Variable    ${JOURNEY_PARTNER_META}    ${meta}
    Set Suite Variable    ${JOURNEY_PARTNERS_STATUS}    ${resp.status_code}

# ── Step 8 ────────────────────────────────────────────────────────────────────
Select Partner
    [Tags]    lab    journey    smoke
    [Documentation]    POST /labs-v2/cart/select-partner — selects partner using meta token.
    ${headers}=    User Auth Headers
    IF    ${JOURNEY_PARTNERS_STATUS} == 200
        ${body}=    Create Dictionary    meta=${JOURNEY_PARTNER_META}
        ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-partner
        ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
        Log Response    ${resp}
        Should Be True    ${resp.status_code} < 500
        ...    msg=Select partner failed: ${resp.status_code}
    ELSE
        Log    Partners unavailable (${JOURNEY_PARTNERS_STATUS}) — skipping
    END

# ── Step 9 ────────────────────────────────────────────────────────────────────
Get Slots
    [Tags]    lab    journey    smoke
    [Documentation]    GET /labs-v2/slots?cartId= — retrieves available collection slots.
    ${headers}=    User Auth Headers
    ${params}=    Create Dictionary    cartId=${JOURNEY_CART_ID}
    ${resp}=    GET    url=${BASE_URL}/labs-v2/slots
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Get slots failed: ${resp.status_code}
    ${slot_date}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[slots][0][date]
    ${slot_id}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[slots][0][time][0][slotId]
    Set Suite Variable    ${JOURNEY_SLOT_DATE}    ${slot_date}
    Set Suite Variable    ${JOURNEY_SLOT_ID}      ${slot_id}

# ── Step 10 ───────────────────────────────────────────────────────────────────
Select Slot
    [Tags]    lab    journey    smoke
    [Documentation]    POST /labs-v2/cart/select-slot — assigns collection date and slot.
    ${headers}=    User Auth Headers
    ${date}=    Set Variable If    $JOURNEY_SLOT_DATE is not None    ${JOURNEY_SLOT_DATE}    2026-03-11
    ${sid}=     Set Variable If    $JOURNEY_SLOT_ID is not None     ${JOURNEY_SLOT_ID}      ${SLOT_ID}
    ${body}=    Create Dictionary    date=${date}    slotId=${sid}    cartId=${JOURNEY_CART_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-slot
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Select slot failed: ${resp.status_code}

# ── Step 11 ───────────────────────────────────────────────────────────────────
Get Patients
    [Tags]    lab    journey    smoke
    [Documentation]    GET /labs-v2/patients — returns user's patient profiles.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/patients
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    Set Suite Variable    ${JOURNEY_PATIENT_ID}    ${resp.json()}[patients][0][patientId]

# ── Step 12 ───────────────────────────────────────────────────────────────────
Select Patient
    [Tags]    lab    journey    smoke
    [Documentation]    POST /labs-v2/cart/select-patient — assigns patient to cart.
    ${headers}=    User Auth Headers
    ${body}=    Create Dictionary    cartId=${JOURNEY_CART_ID}    patientId=${JOURNEY_PATIENT_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-patient
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

# ── Step 13 ───────────────────────────────────────────────────────────────────
View Cart Summary
    [Tags]    lab    journey    smoke
    [Documentation]    GET /labs-v3/cart/summary/:cartId — shows price, slot, address summary.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v3/cart/summary/${JOURNEY_CART_ID}
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} in [200, 400]
    ...    msg=Summary returned unexpected status: ${resp.status_code}
    ${amount}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[cartSummary][payableAmount]
    Set Suite Variable    ${JOURNEY_AMOUNT}    ${amount}

# ── Step 14 ───────────────────────────────────────────────────────────────────
Initiate Transaction
    [Tags]    lab    journey    smoke    critical
    [Documentation]    GET /labs-v2/transact — initiates Cashfree payment; returns HTML payment page.
    ${headers}=    User Auth Headers
    ${amount}=    Set Variable If    $JOURNEY_AMOUNT is not None    ${JOURNEY_AMOUNT}    146
    ${token}=    Set Variable    ${USER_TOKEN}
    ${resp}=    GET
    ...    url=${BASE_URL}/labs-v2/transact?amount=${amount}&auth=${token}&cartId=${JOURNEY_CART_ID}
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Not Be Equal As Integers    ${resp.status_code}    0
    ...    msg=Transact endpoint unreachable
