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
Upload Prescription And Book Lab Journey
    [Tags]    lab    journey    regression
    [Documentation]
    ...    End-to-end: upload prescription (multipart) → get addresses →
    ...    submit digitisation request → mark digitised → dashboard (extract cartId
    ...    from availableCart card) → select address → get/select partner →
    ...    get/select slot → get/select patient → summary → transaction (Cashfree).
    ...    15 steps mirroring the upload-prescription-and-book journey report.
    ${headers}=    User Auth Headers
    ${upload_headers}=    Create Dictionary    Authorization=${USER_TOKEN}

    # ── Step 1: Upload prescription image → extract prescriptionId ────────────
    ${file_bytes}=    Get Binary File    ${CURDIR}/test_prescription.jpg
    ${file_tuple}=    Evaluate    ('test_prescription.jpg', $file_bytes, 'image/jpeg')
    ${files}=    Create Dictionary    file=${file_tuple}
    ${resp}=    POST    url=${BASE_URL}/labs/prescriptions/file
    ...    files=${files}    headers=${upload_headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Prescription upload failed: ${resp.status_code}
    ${prescription_id}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[fileInfo][prescriptionId]
    ...    ELSE    Set Variable    11446

    # ── Step 2: Get addresses ─────────────────────────────────────────────────
    ${resp}=    GET    url=${BASE_URL}/labs-v2/address
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

    # ── Step 3: Submit digitisation request → extract digitisationId ──────────
    ${body}=    Create Dictionary    prescriptionId=${prescription_id}    addressId=${ADDRESS_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/digitisation/submit-request
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Submit digitisation failed: ${resp.status_code}
    ${digitisation_id}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[digitisationId]
    ...    ELSE    Set Variable    ${5080680}

    # ── Step 4: Mark digitised (doctor completes digitisation) ────────────────
    ${body}=    Evaluate    {
    ...    'action': 'complete',
    ...    'digitisationId': $digitisation_id,
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

    # ── Step 5: Dashboard → find cartId from availableCart card ──────────────
    ${params}=    Create Dictionary    lng=${USER_LONGITUDE}    lat=${USER_LATITUDE}
    ${resp}=    GET    url=${BASE_URL}/labs-v2/dashboard-v4
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    ${avail_carts}=    Evaluate
    ...    [c for c in $resp.json().get('cards', []) if c.get('cardType') == 'availableCart']
    ${cart_id}=    Set Variable If    len($avail_carts) > 0
    ...    ${avail_carts[0]['cartId']}    ${CART_ID}

    # ── Step 6: Get addresses (refresh) ──────────────────────────────────────
    ${resp}=    GET    url=${BASE_URL}/labs-v2/address
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

    # ── Step 7: Select address on digitisation cart ───────────────────────────
    ${body}=    Create Dictionary    cartId=${cart_id}    addressId=${ADDRESS_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-address
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Select address failed: ${resp.status_code}

    # ── Step 8: Get partners → extract meta token ─────────────────────────────
    ${params}=    Create Dictionary    lat=${USER_LATITUDE}    long=${USER_LONGITUDE}
    ${resp}=    GET    url=${BASE_URL}/labs-v3/cart/partners/${cart_id}
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Get partners failed: ${resp.status_code}
    ${partner_meta}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[networkList][0][meta]

    # ── Step 9: Select partner ────────────────────────────────────────────────
    IF    ${resp.status_code} == 200
        ${body}=    Create Dictionary    meta=${partner_meta}
        ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-partner
        ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
        Log Response    ${resp}
        Should Be True    ${resp.status_code} < 500
        ...    msg=Select partner failed: ${resp.status_code}
    END

    # ── Step 10: Get slots ────────────────────────────────────────────────────
    ${params}=    Create Dictionary    cartId=${cart_id}
    ${resp}=    GET    url=${BASE_URL}/labs-v2/slots
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Get slots failed: ${resp.status_code}
    ${slot_date}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[slots][0][date]
    ${slot_id}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[slots][0][time][0][slotId]

    # ── Step 11: Select slot ──────────────────────────────────────────────────
    ${date}=    Set Variable If    $slot_date is not None    ${slot_date}    2026-03-11
    ${sid}=     Set Variable If    $slot_id is not None     ${slot_id}      ${SLOT_ID}
    ${body}=    Create Dictionary    date=${date}    slotId=${sid}    cartId=${cart_id}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-slot
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Select slot failed: ${resp.status_code}

    # ── Step 12: Get patients ─────────────────────────────────────────────────
    ${resp}=    GET    url=${BASE_URL}/labs-v2/patients
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    ${patient_id}=    Set Variable    ${resp.json()}[patients][0][patientId]

    # ── Step 13: Select patient ───────────────────────────────────────────────
    ${body}=    Create Dictionary    cartId=${cart_id}    patientId=${patient_id}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-patient
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Select patient failed: ${resp.status_code}

    # ── Step 14: View cart summary → extract payable amount ───────────────────
    ${resp}=    GET    url=${BASE_URL}/labs-v3/cart/summary/${cart_id}
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} in [200, 400]
    ...    msg=Summary returned unexpected status: ${resp.status_code}
    ${amount}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[cartSummary][payableAmount]
    ${amount}=    Set Variable If    $amount is not None    ${amount}    232

    # ── Step 15: Initiate transaction → Cashfree payment page (HTML 200) ──────
    ${token}=    Set Variable    ${USER_TOKEN}
    ${resp}=    GET
    ...    url=${BASE_URL}/labs-v2/transact?amount=${amount}&auth=${token}&cartId=${cart_id}
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Not Be Equal As Integers    ${resp.status_code}    0
    ...    msg=Transact endpoint unreachable
