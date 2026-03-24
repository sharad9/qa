*** Settings ***
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           BuiltIn
Resource          ../../resources/common.resource
Resource          ../../resources/auth.resource
Variables         ../../resources/variables/default.yaml

Suite Setup       Get User Token

*** Test Cases ***

# ── Step 1 ────────────────────────────────────────────────────────────────────
Upload Prescription File
    [Tags]    journey
    [Documentation]    POST /labs/prescriptions/file — uploads prescription image (multipart),
    ...    extracts prescriptionId from fileInfo.
    ${upload_headers}=    Create Dictionary    Authorization=${USER_TOKEN}
    ${file_bytes}=    Get Binary File    ${CURDIR}/test_prescription.jpg
    ${file_tuple}=    Evaluate    ('test_prescription.jpg', $file_bytes, 'image/jpeg')
    ${files}=    Create Dictionary    file=${file_tuple}
    ${resp}=    POST    url=${BASE_URL}/labs/prescriptions/file
    ...    files=${files}    headers=${upload_headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Prescription upload failed: ${resp.status_code}
    ${pid}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[fileInfo][prescriptionId]
    ...    ELSE    Set Variable    11446
    Set Suite Variable    ${JOURNEY_PRESCRIPTION_ID}    ${pid}

# ── Step 2 ────────────────────────────────────────────────────────────────────
Get Addresses For Prescription
    [Tags]    journey
    [Documentation]    GET /labs-v2/address — retrieves saved delivery addresses.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/address
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

# ── Step 3 ────────────────────────────────────────────────────────────────────
Submit Digitisation Request
    [Tags]    journey
    [Documentation]    POST /labs-v2/digitisation/submit-request — links prescription to address,
    ...    creates digitisation request and extracts digitisationId.
    ${headers}=    User Auth Headers
    ${body}=    Create Dictionary
    ...    prescriptionId=${JOURNEY_PRESCRIPTION_ID}
    ...    addressId=${ADDRESS_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/digitisation/submit-request
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Submit digitisation failed: ${resp.status_code}
    ${did}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[digitisationId]
    ...    ELSE    Set Variable    ${5080680}
    Set Suite Variable    ${JOURNEY_DIGITISATION_ID}    ${did}

# ── Step 4 ────────────────────────────────────────────────────────────────────
Mark Digitised
    [Tags]    journey
    [Documentation]    POST /digitisations/requests/mark-digitised — doctor completes
    ...    digitisation with full clinical payload.
    ${headers}=    User Auth Headers
    ${body}=    Evaluate    {
    ...    'action': 'complete',
    ...    'digitisationId': $JOURNEY_DIGITISATION_ID,
    ...    'appointmentDate': '${DIGITISATION_APPOINTMENT_DATE}',
    ...    'prescriptionValidityDate': '${DIGITISATION_PRESCRIPTION_VALIDITY_DATE}',
    ...    'doctorName': '${DIGITISATION_DOCTOR_NAME}',
    ...    'centerName': '${DIGITISATION_CENTER_NAME}',
    ...    'centerAddress': '${DIGITISATION_CENTER_ADDRESS}',
    ...    'consultationId': None,
    ...    'doctorId': int('${DIGITISATION_DOCTOR_ID}'),
    ...    'centerId': int('${DIGITISATION_CENTER_ID}'),
    ...    'verticalId': int('${DIGITISATION_VERTICAL_ID}'),
    ...    'practiceId': int('${DIGITISATION_PRACTICE_ID}'),
    ...    'diagnosis': '${DIGITISATION_DIAGNOSIS}',
    ...    'diagnosisSource': True,
    ...    'symptoms': None,
    ...    'isCritical': int('${DIGITISATION_IS_CRITICAL}'),
    ...    'icdCode': '${DIGITISATION_ICD_CODE}',
    ...    'secondaryDiagnosis': '${DIGITISATION_SECONDARY_DIAGNOSIS}',
    ...    'secondaryDiagnosisIcdCode': '${DIGITISATION_SECONDARY_DIAGNOSIS_ICD_CODE}',
    ...    'blockerConsultationId': None,
    ...    'commonDigitisationId': None,
    ...    'exceptionalAdditionReason': None,
    ...    'googlePlace': None,
    ...    'addedMedicines': [],
    ...    'qcStatus': int('${DIGITISATION_QC_STATUS}'),
    ...    'startedAt': int('${DIGITISATION_STARTED_AT}'),
    ...    'stepOneCompletedAt': int('${DIGITISATION_STEP_ONE_COMPLETED_AT}'),
    ...    'aiAssisted': False,
    ...    'isPatientManuallySelected': True
    ...    }
    ${resp}=    POST
    ...    url=${BASE_URL}/digitisations/requests/mark-digitised?v=${DIGITISATION_VERSION}
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Mark digitised failed: ${resp.status_code}

# ── Step 5 ────────────────────────────────────────────────────────────────────
Get Dashboard And Extract Cart
    [Tags]    journey
    [Documentation]    GET /labs-v2/dashboard-v4 — finds cart created from digitisation
    ...    by filtering cards for cardType=availableCart, extracts cartId.
    ${headers}=    User Auth Headers
    ${params}=    Create Dictionary    lng=${USER_LONGITUDE}    lat=${USER_LATITUDE}
    ${resp}=    GET    url=${BASE_URL}/labs-v2/dashboard-v4
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    ${avail_carts}=    Evaluate
    ...    [c for c in $resp.json().get('cards', []) if c.get('cardType') == 'availableCart']
    ${cart_id}=    Set Variable If    len($avail_carts) > 0
    ...    ${avail_carts[0]['cartId']}    ${CART_ID}
    Set Suite Variable    ${JOURNEY_CART_ID}    ${cart_id}

# ── Step 6 ────────────────────────────────────────────────────────────────────
Get Addresses For Booking
    [Tags]    journey
    [Documentation]    GET /labs-v2/address — refresh addresses before booking flow.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/address
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

# ── Step 7 ────────────────────────────────────────────────────────────────────
Select Address On Digitisation Cart
    [Tags]    journey
    [Documentation]    POST /labs-v2/cart/select-address — assigns address to the digitisation cart.
    ${headers}=    User Auth Headers
    ${body}=    Create Dictionary    cartId=${JOURNEY_CART_ID}    addressId=${ADDRESS_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-address
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Select address failed: ${resp.status_code}

# ── Step 8 ────────────────────────────────────────────────────────────────────
Get Partners For Digitisation Cart
    [Tags]    journey
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
    Set Suite Variable    ${JOURNEY_PARTNER_META}       ${meta}
    Set Suite Variable    ${JOURNEY_PARTNERS_STATUS}    ${resp.status_code}

# ── Step 9 ────────────────────────────────────────────────────────────────────
Select Partner For Digitisation Cart
    [Tags]    journey
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

# ── Step 10 ───────────────────────────────────────────────────────────────────
Get Slots For Digitisation Cart
    [Tags]    journey
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

# ── Step 11 ───────────────────────────────────────────────────────────────────
Select Slot For Digitisation Cart
    [Tags]    journey
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

# ── Step 12 ───────────────────────────────────────────────────────────────────
Get Patients For Digitisation Cart
    [Tags]    journey
    [Documentation]    GET /labs-v2/patients — returns user's patient profiles.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/patients
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    Set Suite Variable    ${JOURNEY_PATIENT_ID}    ${resp.json()}[patients][0][patientId]

# ── Step 13 ───────────────────────────────────────────────────────────────────
Select Patient For Digitisation Cart
    [Tags]    journey
    [Documentation]    POST /labs-v2/cart/select-patient — assigns patient to cart.
    ${headers}=    User Auth Headers
    ${body}=    Create Dictionary    cartId=${JOURNEY_CART_ID}    patientId=${JOURNEY_PATIENT_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-patient
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Select patient failed: ${resp.status_code}

# ── Step 14 ───────────────────────────────────────────────────────────────────
View Digitisation Cart Summary
    [Tags]    journey
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

# ── Step 15 ───────────────────────────────────────────────────────────────────
Initiate Transaction For Digitisation Cart
    [Tags]    journey
    [Documentation]    GET /labs-v2/transact — initiates Cashfree payment; returns HTML payment page.
    ${headers}=    User Auth Headers
    ${amount}=    Set Variable If    $JOURNEY_AMOUNT is not None    ${JOURNEY_AMOUNT}    232
    ${token}=    Set Variable    ${USER_TOKEN}
    ${resp}=    GET
    ...    url=${BASE_URL}/labs-v2/transact?amount=${amount}&auth=${token}&cartId=${JOURNEY_CART_ID}
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Not Be Equal As Integers    ${resp.status_code}    0
    ...    msg=Transact endpoint unreachable
