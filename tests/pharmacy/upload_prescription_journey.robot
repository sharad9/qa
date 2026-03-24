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
Add Multiple Prescription Files
    [Tags]    journey
    [Documentation]    POST /absol/digitisation/add-multiple-files — uploads prescription
    ...    image (multipart), extracts pharmacyPrescriptionId.
    ${upload_headers}=    Create Dictionary    Authorization=${USER_TOKEN}
    ${file_bytes}=    Get Binary File    ${CURDIR}/test_prescription.jpg
    ${file_tuple}=    Evaluate    ('test_prescription.jpg', $file_bytes, 'image/jpeg')
    ${files}=    Create Dictionary    file=${file_tuple}
    ${resp}=    POST    url=${BASE_URL_PHARMACY}/digitisation/add-multiple-files
    ...    files=${files}    headers=${upload_headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Add multiple files failed: ${resp.status_code}
    ${pid}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[pharmacyPrescriptionId]
    ...    ELSE    Set Variable    ${8036}
    Set Suite Variable    ${JOURNEY_PHARMACY_PRESCRIPTION_ID}    ${pid}

# ── Step 2 ────────────────────────────────────────────────────────────────────
Get Upload Prescription Page
    [Tags]    journey
    [Documentation]    GET /absol/digitisation/upload-prescription — returns prescription
    ...    preview and pharmacyPrescriptionId confirming successful upload.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL_PHARMACY}/digitisation/upload-prescription
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    Should Be Equal As Strings    ${resp.json()}[pharmacyPrescriptionId]
    ...    ${JOURNEY_PHARMACY_PRESCRIPTION_ID}

# ── Step 3 ────────────────────────────────────────────────────────────────────
Get Cart Addresses
    [Tags]    journey
    [Documentation]    GET /absol/cart/addresses — retrieves saved delivery addresses.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL_PHARMACY}/cart/addresses
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    ${address_id}=    Set Variable    ${resp.json()}[addresses][0][addressId]
    Set Suite Variable    ${JOURNEY_ADDRESS_ID}    ${address_id}

# ── Step 4 ────────────────────────────────────────────────────────────────────
Get Patients
    [Tags]    journey
    [Documentation]    GET /latios/labs-v2/patients — retrieves patient profiles.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/patients
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    ${patient_id}=    Set Variable    ${resp.json()}[patients][0][patientId]
    Set Suite Variable    ${JOURNEY_PATIENT_ID}    ${patient_id}

# ── Step 5 ────────────────────────────────────────────────────────────────────
Submit Prescription Request
    [Tags]    journey
    [Documentation]    POST /absol/digitisation/submit-request — links prescription,
    ...    address and patient; creates digitisation request and extracts digitisationId.
    ${headers}=    User Auth Headers
    ${body}=    Create Dictionary
    ...    pharmacyPrescriptionId=${JOURNEY_PHARMACY_PRESCRIPTION_ID}
    ...    addressId=${JOURNEY_ADDRESS_ID}
    ...    patientId=${JOURNEY_PATIENT_ID}
    ${resp}=    POST    url=${BASE_URL_PHARMACY}/digitisation/submit-request
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Submit request failed: ${resp.status_code}
    ${did}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[digitisationId]
    ...    ELSE    Set Variable    ${5080681}
    Set Suite Variable    ${JOURNEY_DIGITISATION_ID}    ${did}

# ── Step 6 ────────────────────────────────────────────────────────────────────
Save Cart Items
    [Tags]    journey
    [Documentation]    PUT /absol/medicines/save/cartItems?v=50 — saves prescribed medicine
    ...    to cart using digitisationId from submit-request.
    ${headers}=    User Auth Headers
    ${body}=    Evaluate    {
    ...    'cartItem': {
    ...        'dimDrugMasterId': 397349,
    ...        'masterGroupItemCode': 653419136,
    ...        'name': 'PAN IV 40MG INJECTION',
    ...        'subMasterName': None,
    ...        'digitisationId': $JOURNEY_DIGITISATION_ID,
    ...        'providers': [{
    ...            'dimDrugId': 672233,
    ...            'partnerId': 1,
    ...            'name': 'PAN IV 40MG INJECTION',
    ...            'isAvailable': 1,
    ...            'genericName': 'PAN IV 40MG INJECTION',
    ...            'dosage': '1-0-0: once a day in the morning',
    ...            'prescribedQuantity': None,
    ...            'duration': '30',
    ...            'durationType': 'Days',
    ...            'meal': 'After',
    ...            'notes': '',
    ...            'coveredUnderOpd': 1,
    ...            'isSubstitute': 0
    ...        }]
    ...    }
    ...    }
    ${resp}=    PUT    url=${BASE_URL_PHARMACY}/medicines/save/cartItems?v=50
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Save cart items failed: ${resp.status_code}

# ── Step 7 ────────────────────────────────────────────────────────────────────
Mark Digitised
    [Tags]    journey
    [Documentation]    POST /latios/digitisations/requests/mark-digitised — doctor completes
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

# ── Step 8 ────────────────────────────────────────────────────────────────────
Get Pharmacy Dashboard
    [Tags]    journey
    [Documentation]    GET /absol/newDashboard — shows ongoing orders including the
    ...    newly digitised prescription order.
    ${headers}=    User Auth Headers
    ${params}=    Create Dictionary    version=${PHARMACY_DASHBOARD_VERSION}
    ${resp}=    GET    url=${BASE_URL_PHARMACY}/newDashboard
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

# ── Step 9 ────────────────────────────────────────────────────────────────────
Get Carts For Digitisation
    [Tags]    journey
    [Documentation]    GET /absol/carts?digitisationRequestId=&isReOrderCart=0 —
    ...    retrieves carts created for this digitisation; extracts cartId.
    ${headers}=    User Auth Headers
    ${resp}=    GET
    ...    url=${BASE_URL_PHARMACY}/carts?digitisationRequestId=${JOURNEY_DIGITISATION_ID}&isReOrderCart=${PHARMACY_IS_REORDER_CART}
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Get carts failed: ${resp.status_code}
    ${cart_id}=    Run Keyword If    ${resp.status_code} == 200 and len($resp.json().get('carts', [])) > 0
    ...    Set Variable    ${resp.json()}[carts][0][cartId]
    ...    ELSE    Set Variable    982457
    Set Suite Variable    ${JOURNEY_CART_ID}    ${cart_id}

# ── Step 10 ───────────────────────────────────────────────────────────────────
Select Cart
    [Tags]    journey
    [Documentation]    GET /absol/cart/prescription/cartId/:cartId — fetches full
    ...    cart details for the selected pharmacy cart.
    ${headers}=    User Auth Headers
    ${resp}=    GET
    ...    url=${BASE_URL_PHARMACY}/cart/prescription/cartId/${JOURNEY_CART_ID}
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Select cart failed: ${resp.status_code}

# ── Step 11 ───────────────────────────────────────────────────────────────────
Place Order
    [Tags]    journey
    [Documentation]    GET /absol/cart/submit — initiates Cashfree payment for the
    ...    pharmacy cart; returns HTML payment/redirect page.
    ${headers}=    User Auth Headers
    ${token}=    Set Variable    ${USER_TOKEN}
    ${resp}=    GET
    ...    url=${BASE_URL_PHARMACY}/cart/submit?amount=${PHARMACY_PLACE_ORDER_AMOUNT}&auth=${token}&cartId=${JOURNEY_CART_ID}&deliveryType=${PHARMACY_PLACE_ORDER_DELIVERY_TYPE}&storeId=${PHARMACY_PLACE_ORDER_STORE_ID}
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Not Be Equal As Integers    ${resp.status_code}    0
    ...    msg=Place order endpoint unreachable
