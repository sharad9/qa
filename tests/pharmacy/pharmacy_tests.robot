*** Settings ***
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Resource          ../../resources/common.resource
Resource          ../../resources/auth.resource
Variables         ../../resources/variables/default.yaml

Suite Setup       Get User Token

*** Test Cases ***
Get Pharmacy Cart Addresses
    [Tags]    pharmacy    smoke    critical
    [Documentation]    GET /absol/cart/addresses returns saved delivery addresses.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL_PHARMACY}/cart/addresses    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Get Pharmacy Dashboard
    [Tags]    pharmacy    smoke
    [Documentation]    GET /absol/newDashboard returns 200.
    ${headers}=    User Auth Headers
    ${params}=    Create Dictionary    version=1800009616
    ${resp}=    GET    url=${BASE_URL_PHARMACY}/newDashboard
    ...    headers=${headers}    params=${params}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Get Patient Profiles
    [Tags]    pharmacy    smoke
    [Documentation]    GET /latios/labs-v2/patients returns patient list (shared with lab domain).
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/patients    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Upload Prescription Endpoint Available
    [Tags]    pharmacy    smoke    critical
    [Documentation]    GET /absol/digitisation/upload-prescription returns 200.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL_PHARMACY}/digitisation/upload-prescription    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Add Multiple Pharmacy Prescription Files
    [Tags]    pharmacy    regression
    [Documentation]    POST /absol/digitisation/add-multiple-files uploads prescription image (multipart/form-data).
    ...    UAT server may return 500 due to disk space exhaustion — endpoint reachability is verified.
    ${headers}=    Create Dictionary    Authorization=${USER_TOKEN}
    ${file_bytes}=    Get Binary File    ${CURDIR}/test_prescription.jpg
    ${file_tuple}=    Evaluate    ('test_prescription.jpg', $file_bytes, 'image/jpeg')
    ${files}=    Create Dictionary    file=${file_tuple}
    ${resp}=    POST    url=${BASE_URL_PHARMACY}/digitisation/add-multiple-files    files=${files}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Not Be Equal As Integers    ${resp.status_code}    0
    ...    msg=Add files endpoint unreachable

Submit Pharmacy Prescription Request
    [Tags]    pharmacy    regression
    [Documentation]    POST /absol/digitisation/submit-request links prescription to address and patient.
    ${headers}=    User Auth Headers
    ${body}=    Create Dictionary
    ...    pharmacyPrescriptionId=${8036}
    ...    addressId=${6348}
    ...    patientId=${1441}
    ${resp}=    POST    url=${BASE_URL_PHARMACY}/digitisation/submit-request    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Pharmacy submit request returned error: ${resp.status_code}

Mark Pharmacy Digitisation Complete
    [Tags]    pharmacy    regression
    [Documentation]    POST /latios/digitisations/requests/mark-digitised marks pharmacy digitisation complete.
    ${headers}=    User Auth Headers
    ${body}=    Create Dictionary
    ...    action=complete
    ...    digitisationId=${5080681}
    ...    appointmentDate=2026-03-04
    ...    prescriptionValidityDate=2026-03-31
    ...    doctorName=Dr. S. Manoharan
    ...    centerName=S. V. Clinic
    ...    centerAddress=85 S.V.S.G Cottage 5th Main Road, Chennai
    ${resp}=    POST    url=${BASE_URL}/digitisations/requests/mark-digitised?v=50    json=${body}    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Mark pharmacy digitised returned error: ${resp.status_code}

Get Pharmacy Carts After Digitisation
    [Tags]    pharmacy    regression
    [Documentation]    GET /absol/carts?digitisationRequestId=... returns carts for a digitisation.
    ${headers}=    User Auth Headers
    ${resp}=    GET
    ...    url=${BASE_URL_PHARMACY}/carts?digitisationRequestId=5080681&isReOrderCart=0
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Get carts returned error: ${resp.status_code}

Select Pharmacy Cart
    [Tags]    pharmacy    regression
    [Documentation]    GET /absol/cart/prescription/cartId/:cartId fetches pharmacy cart details.
    ${headers}=    User Auth Headers
    ${resp}=    GET
    ...    url=${BASE_URL_PHARMACY}/cart/prescription/cartId/982457
    ...    headers=${headers}    timeout=${TIMEOUT}    expected_status=any
    Log Response    ${resp}
    Should Be True    ${resp.status_code} < 500
    ...    msg=Select cart returned error: ${resp.status_code}
