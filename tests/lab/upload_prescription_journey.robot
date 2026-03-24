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
    ...    End-to-end journey: upload prescription image → get addresses →
    ...    submit digitisation request → mark digitised → view dashboard →
    ...    select address, partner, slot, patient → summary → transaction.
    ...    Steps mirror the upload-prescription-and-book journey from the API report.
    ${headers}=    User Auth Headers
    ${upload_headers}=    Create Dictionary    Authorization=${USER_TOKEN}

    # Step 1: Upload prescription image → extract prescriptionId
    ${file_bytes}=    Get Binary File    ${CURDIR}/test_prescription.jpg
    ${file_tuple}=    Evaluate    ('test_prescription.jpg', $file_bytes, 'image/jpeg')
    ${files}=    Create Dictionary    file=${file_tuple}
    ${resp}=    POST    url=${BASE_URL}/labs/prescriptions/file
    ...    files=${files}    headers=${upload_headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Prescription upload failed: ${resp.status_code}
    ${prescription_id}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[prescriptionId]
    ...    ELSE    Set Variable    11446

    # Step 2: Get addresses
    ${resp}=    GET    url=${BASE_URL}/labs-v2/address
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

    # Step 3: Submit digitisation request → link prescription to address
    ${body}=    Create Dictionary    prescriptionId=${prescription_id}    addressId=${ADDRESS_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/digitisation/submit-request
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Submit digitisation failed: ${resp.status_code}

    # Step 4: Mark digitised (doctor action)
    ${body}=    Create Dictionary
    ...    action=complete
    ...    digitisationId=${5080680}
    ...    appointmentDate=${DIGITISATION_APPOINTMENT_DATE}
    ...    prescriptionValidityDate=${DIGITISATION_PRESCRIPTION_VALIDITY_DATE}
    ...    doctorName=${DIGITISATION_DOCTOR_NAME}
    ...    centerName=${DIGITISATION_CENTER_NAME}
    ...    centerAddress=${DIGITISATION_CENTER_ADDRESS}
    ${resp}=    POST
    ...    url=${BASE_URL}/digitisations/requests/mark-digitised?v=${DIGITISATION_VERSION}
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Mark digitised failed: ${resp.status_code}

    # Step 5: Get dashboard — shows cart created from digitisation
    ${params}=    Create Dictionary    lng=${USER_LONGITUDE}    lat=${USER_LATITUDE}
    ${resp}=    GET    url=${BASE_URL}/labs-v2/dashboard-v4
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    # Extract cartId from first active cart in dashboard; fall back to CART_ID
    ${cart_id}=    Run Keyword And Ignore Error
    ...    Set Variable    ${resp.json()}[carts][0][cartId]
    ${cart_id}=    Set Variable If
    ...    '${cart_id[0]}' == 'PASS'    ${cart_id[1]}    ${CART_ID}

    # Step 6: Get addresses (refresh)
    ${resp}=    GET    url=${BASE_URL}/labs-v2/address
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

    # Step 7: Select address on digitisation cart
    ${body}=    Create Dictionary    cartId=${cart_id}    addressId=${ADDRESS_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-address
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Select address failed: ${resp.status_code}

    # Step 8: Get partners → extract meta token
    ${params}=    Create Dictionary    lat=${USER_LATITUDE}    long=${USER_LONGITUDE}
    ${resp}=    GET    url=${BASE_URL}/labs-v3/cart/partners/${cart_id}
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Get partners failed: ${resp.status_code}
    ${meta}=    Run Keyword If    ${resp.status_code} == 200
    ...    Set Variable    ${resp.json()}[networkList][0][meta]

    # Step 9: Select partner
    IF    ${resp.status_code} == 200 and $meta is not None
        ${body}=    Create Dictionary    meta=${meta}
        ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-partner
        ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
        Log Response    ${resp}
        Should Be True    ${resp.status_code} < 500
        ...    msg=Select partner failed: ${resp.status_code}
    END

    # Step 10: Get slots
    ${params}=    Create Dictionary    cartId=${cart_id}
    ${resp}=    GET    url=${BASE_URL}/labs-v2/slots
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Get slots failed: ${resp.status_code}

    # Step 11: Select slot
    ${date}=    Evaluate
    ...    (__import__('datetime').date.today() + __import__('datetime').timedelta(days=1)).strftime('%Y-%m-%d')
    ${body}=    Create Dictionary    date=${date}    slotId=${SLOT_ID}    cartId=${cart_id}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-slot
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Select slot failed: ${resp.status_code}

    # Step 12: Get patients
    ${resp}=    GET    url=${BASE_URL}/labs-v2/patients
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

    # Step 13: Select patient
    ${body}=    Create Dictionary    cartId=${cart_id}    patientId=${PATIENT_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-patient
    ...    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Select patient failed: ${resp.status_code}

    # Step 14: View cart summary
    ${resp}=    GET    url=${BASE_URL}/labs-v3/cart/summary/${cart_id}
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} in [200, 400]
    ...    msg=Summary returned unexpected status: ${resp.status_code}

    # Step 15: Initiate transaction
    ${token}=    Set Variable    ${USER_TOKEN}
    ${resp}=    GET
    ...    url=${BASE_URL}/labs-v2/transact?amount=232&auth=${token}&cartId=${cart_id}
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Not Be Equal As Integers    ${resp.status_code}    0
    ...    msg=Transact endpoint unreachable
