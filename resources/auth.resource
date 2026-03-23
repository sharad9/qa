*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    BuiltIn
Variables  variables/default.yaml

*** Keywords ***
Get User Token
    [Documentation]    Login via phone + OTP and return JWT token.
    ...                If USER_TOKEN is already set globally (from a previous suite), reuse it.
    ${existing}=    Get Variable Value    ${USER_TOKEN}    ${EMPTY}
    Run Keyword If    '${existing}' != '${EMPTY}'    Return From Keyword    ${existing}
    ${body}=    Create Dictionary    phone=${USER_PHONE}    countryCode=${91}    platform=WEB
    ${resp}=    POST    ${BASE_URL}/new-auth/login-phone    json=${body}    expected_status=any
    Log    Status: ${resp.status_code} Body: ${resp.text}
    Run Keyword If    ${resp.status_code} != 200
    ...    Fail    login-phone failed: ${resp.text}
    ${body2}=    Create Dictionary    phone=${USER_PHONE}    otp=${USER_OTP}    platform=WEB
    ${resp2}=    POST    ${BASE_URL}/new-auth/otp    json=${body2}    expected_status=any
    Log    Status: ${resp2.status_code} Body: ${resp2.text}
    Run Keyword If    ${resp2.status_code} != 200
    ...    Fail    otp verification failed: ${resp2.text}
    ${token}=    Set Variable    ${resp2.headers}[authorization]
    Set Global Variable    ${USER_TOKEN}    ${token}
    [Return]    ${token}

Get Doctor Token
    [Documentation]    Login as doctor and return JWT token.
    ...                If DOCTOR_TOKEN is already set globally (from a previous suite), reuse it.
    ${existing}=    Get Variable Value    ${DOCTOR_TOKEN}    ${EMPTY}
    Run Keyword If    '${existing}' != '${EMPTY}'    Return From Keyword    ${existing}
    ${body}=    Create Dictionary    email=${DOCTOR_EMAIL}    password=${DOCTOR_PASSWORD}    platform=WEB    v=50
    ${resp}=    POST    ${BASE_URL}/new-auth/doctor/login    json=${body}    expected_status=any
    Log    Status: ${resp.status_code} Body: ${resp.text}
    Run Keyword If    ${resp.status_code} != 200
    ...    Fail    Doctor login failed: ${resp.text}
    ${token}=    Set Variable    ${resp.headers}[authorization]
    Set Global Variable    ${DOCTOR_TOKEN}    ${token}
    [Return]    ${token}

User Auth Headers
    [Documentation]    Return Authorization header dict for user token.
    ${token}=    Get Variable Value    ${USER_TOKEN}    ${EMPTY}
    ${headers}=    Create Dictionary    Authorization=${token}    Content-Type=application/json
    [Return]    ${headers}

Doctor Auth Headers
    [Documentation]    Return Authorization header dict for doctor token.
    ${token}=    Get Variable Value    ${DOCTOR_TOKEN}    ${EMPTY}
    ${headers}=    Create Dictionary    Authorization=${token}    Content-Type=application/json
    [Return]    ${headers}
