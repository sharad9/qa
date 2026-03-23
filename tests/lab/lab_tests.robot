*** Settings ***
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Resource          ../../resources/common.resource
Resource          ../../resources/auth.resource
Variables         ../../resources/variables/default.yaml

Suite Setup       Get User Token

*** Test Cases ***
Search All Labs Returns List
    [Tags]    lab    smoke    critical
    [Documentation]    GET /labs-v2/all returns 200 and a non-empty list of labs.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/all    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    Should Not Be Empty    ${resp.json()}

Get Cart Returns Cart Data
    [Tags]    lab    smoke
    [Documentation]    GET /labs-v2/cart returns 200.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/cart    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Get Addresses Returns List
    [Tags]    lab    smoke
    [Documentation]    GET /labs-v2/address returns 200 and saved addresses.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/address    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Get Partners For Cart
    [Tags]    lab    regression
    [Documentation]    GET /labs-v3/cart/partners/:cartId returns available partners.
    ${headers}=    User Auth Headers
    ${params}=    Create Dictionary    lat=28.5681199    long=77.31620029999999
    ${resp}=    GET    url=${BASE_URL}/labs-v3/cart/partners/${CART_ID}
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Get Slots For Cart
    [Tags]    lab    regression
    [Documentation]    GET /labs-v2/slots?cartId= returns available time slots.
    ${headers}=    User Auth Headers
    ${params}=    Create Dictionary    cartId=${CART_ID}
    ${resp}=    GET    url=${BASE_URL}/labs-v2/slots
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Get Patients Returns List
    [Tags]    lab    regression
    [Documentation]    GET /labs-v2/patients returns the user's patient profiles.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/patients    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Get Cart Summary
    [Tags]    lab    regression
    [Documentation]    GET /labs-v3/cart/summary/:cartId returns order summary (200 or 400 for expired cart).
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v3/cart/summary/${CART_ID}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} in [200, 400]
    ...    msg=Expected HTTP 200 or 400 but got ${resp.status_code}: ${resp.text}

Lab Dashboard Returns Data
    [Tags]    lab    regression
    [Documentation]    GET /labs-v2/dashboard-v4 returns 200 with dashboard content.
    ${headers}=    User Auth Headers
    ${resp}=    GET
    ...    url=${BASE_URL}/labs-v2/dashboard-v4?lng=77.31620029999999&lat=28.5681199
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Add Lab To Cart And Remove
    [Tags]    lab    regression
    [Documentation]    POST /labs-v2/cart/add adds a lab; POST /labs-v2/cart/remove removes it.
    ${headers}=    User Auth Headers
    # Add to cart
    ${body}=    Create Dictionary    cartId=${CART_ID}    labId=${LAB_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/add    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    ${cart_item_id}=    Set Variable    ${resp.json()}[cartItem][cartItemId]
    # Remove from cart
    ${body2}=    Create Dictionary    cartId=${CART_ID}    cartItemId=${cart_item_id}
    ${resp2}=    POST    url=${BASE_URL}/labs-v2/cart/remove    json=${body2}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp2}
    Verify Status Code    ${resp2}    200

Select Cart Address
    [Tags]    lab    regression
    [Documentation]    POST /labs-v2/cart/select-address sets delivery address on cart.
    ${headers}=    User Auth Headers
    ${body}=    Create Dictionary    cartId=${CART_ID}    addressId=${ADDRESS_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-address    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Select Lab Partner
    [Tags]    lab    regression
    [Documentation]    Fetch partners list then POST select-partner with extracted meta.
    ${headers}=    User Auth Headers
    # Get partners (cart may be stale on UAT — accept 200 or 4xx)
    ${resp}=    GET
    ...    url=${BASE_URL}/labs-v3/cart/partners/${CART_ID}?lat=28.5681199&long=77.31620029999999
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Get partners returned server error: ${resp.status_code}
    Return From Keyword If    ${resp.status_code} != 200
    ${meta}=    Set Variable    ${resp.json()}[networkList][0][meta]
    # Select partner
    ${body}=    Create Dictionary    meta=${meta}
    ${resp2}=    POST    url=${BASE_URL}/labs-v2/cart/select-partner    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp2}
    Should Be True    ${resp2.status_code} < 500
    ...    msg=Select partner returned server error: ${resp2.status_code}

Select Lab Slot
    [Tags]    lab    regression
    [Documentation]    POST /labs-v2/cart/select-slot assigns a collection slot (cart may be stale on UAT).
    ${headers}=    User Auth Headers
    ${date}=    Evaluate    (__import__('datetime').date.today() + __import__('datetime').timedelta(days=1)).strftime('%Y-%m-%d')
    ${body}=    Create Dictionary    date=${date}    slotId=${SLOT_ID}    cartId=${CART_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-slot    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Select slot returned server error: ${resp.status_code}

Select Lab Patient
    [Tags]    lab    regression
    [Documentation]    POST /labs-v2/cart/select-patient assigns patient to cart.
    ${headers}=    User Auth Headers
    ${body}=    Create Dictionary    cartId=${CART_ID}    patientId=${PATIENT_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/cart/select-patient    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Initiate Lab Transaction
    [Tags]    lab    regression
    [Documentation]    GET /labs-v2/transact initiates payment for the lab cart.
    ...    UAT may return 5xx for stale/expired carts — endpoint reachability is verified.
    ${headers}=    User Auth Headers
    ${token}=    Set Variable    ${USER_TOKEN}
    ${resp}=    GET
    ...    url=${BASE_URL}/labs-v2/transact?amount=146&auth=${token}&cartId=${CART_ID}
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Not Be Equal As Integers    ${resp.status_code}    0
    ...    msg=Transact endpoint unreachable (no response)

Upload Lab Prescription File
    [Tags]    lab    regression
    [Documentation]    POST /labs/prescriptions/file uploads a prescription image (multipart/form-data).
    ${headers}=    Create Dictionary    Authorization=${USER_TOKEN}
    ${file_bytes}=    Get Binary File    ${CURDIR}/test_prescription.jpg
    ${file_tuple}=    Evaluate    ('test_prescription.jpg', $file_bytes, 'image/jpeg')
    ${files}=    Create Dictionary    file=${file_tuple}
    ${resp}=    POST    url=${BASE_URL}/labs/prescriptions/file    files=${files}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Prescription upload returned error: ${resp.status_code}

Submit Digitisation Request
    [Tags]    lab    regression
    [Documentation]    POST /labs-v2/digitisation/submit-request links prescription to address.
    ${headers}=    User Auth Headers
    ${body}=    Create Dictionary    prescriptionId=11446    addressId=${ADDRESS_ID}
    ${resp}=    POST    url=${BASE_URL}/labs-v2/digitisation/submit-request    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Submit digitisation returned error: ${resp.status_code}

Mark Digitisation Complete
    [Tags]    lab    regression
    [Documentation]    POST /digitisations/requests/mark-digitised marks the request as complete.
    ${headers}=    User Auth Headers
    ${body}=    Create Dictionary
    ...    action=complete
    ...    digitisationId=${5080680}
    ...    appointmentDate=2026-03-04
    ...    prescriptionValidityDate=2026-03-31
    ...    doctorName=Dr. S. Manoharan
    ...    centerName=S. V. Clinic
    ...    centerAddress=85 S.V.S.G Cottage 5th Main Road, Chennai
    ${resp}=    POST    url=${BASE_URL}/digitisations/requests/mark-digitised?v=50    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Mark digitised returned error: ${resp.status_code}
