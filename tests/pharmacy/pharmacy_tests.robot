*** Settings ***
Library           RequestsLibrary
Library           Collections
Resource          ../../resources/common.resource
Resource          ../../resources/auth.resource
Variables         ../../resources/variables/default.yaml

Suite Setup       Get User Token

*** Test Cases ***
Get Pharmacy Cart Addresses
    [Tags]    pharmacy    smoke    critical
    [Documentation]    GET /absol/cart/addresses returns saved delivery addresses.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL_PHARMACY}/cart/addresses    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Get Pharmacy Dashboard
    [Tags]    pharmacy    smoke
    [Documentation]    GET /absol/newDashboard returns 200.
    ${headers}=    User Auth Headers
    ${params}=    Create Dictionary    version=1800009616
    ${resp}=    GET    url=${BASE_URL_PHARMACY}/newDashboard
    ...    headers=${headers}    params=${params}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Get Patient Profiles
    [Tags]    pharmacy    smoke
    [Documentation]    GET /latios/labs-v2/patients returns patient list (shared with lab domain).
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/patients    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200

Upload Prescription Endpoint Available
    [Tags]    pharmacy    smoke    critical
    [Documentation]    GET /absol/digitisation/upload-prescription returns 200.
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL_PHARMACY}/digitisation/upload-prescription    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
