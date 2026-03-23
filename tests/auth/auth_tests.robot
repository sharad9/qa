*** Settings ***
Library           RequestsLibrary
Library           Collections
Resource          ../../resources/common.resource
Resource          ../../resources/auth.resource
Variables         ../../resources/variables/default.yaml

Suite Setup       Get User Token

*** Test Cases ***
Doctor Login Returns JWT
    [Tags]    auth    smoke    critical
    [Documentation]    POST /new-auth/doctor/login returns 200 and Authorization JWT header.
    ${body}=    Create Dictionary
    ...    email=${DOCTOR_EMAIL}
    ...    password=${DOCTOR_PASSWORD}
    ...    platform=WEB
    ...    v=50
    ${resp}=    POST    ${BASE_URL}/new-auth/doctor/login    json=${body}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    Dictionary Should Contain Key    ${resp.headers}    authorization
    Should Start With    ${resp.headers}[authorization]    JWT

User Login Sends OTP
    [Tags]    auth    smoke    critical
    [Documentation]    Verify OTP-based login flow succeeded: suite setup called login-phone and
    ...                received otpSent, then verified OTP. Confirms the full user auth flow works.
    ...                Note: login-phone has a per-window rate limit on UAT; the suite setup performs
    ...                the actual call. This test validates the resulting token is a valid JWT.
    ${token}=    Get Variable Value    ${USER_TOKEN}    ${EMPTY}
    Should Not Be Empty    ${token}    msg=USER_TOKEN is empty — login-phone or OTP flow failed in suite setup
    Should Start With    ${token}    JWT    msg=USER_TOKEN does not start with JWT: ${token}

User OTP Verify Returns Token
    [Tags]    auth    smoke    critical
    [Documentation]    Verify that the OTP verification returned a valid JWT token.
    ...                The suite setup called /new-auth/login-phone then /new-auth/otp — this
    ...                test confirms the token stored from that flow is a valid JWT.
    ${token}=    Get Variable Value    ${USER_TOKEN}    ${EMPTY}
    Should Not Be Empty    ${token}    msg=No USER_TOKEN stored — OTP verification failed in suite setup
    Should Start With    ${token}    JWT    msg=Expected JWT token but got: ${token}
    ${headers}=    User Auth Headers
    ${resp}=    GET    url=${BASE_URL}/labs-v2/patients    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
