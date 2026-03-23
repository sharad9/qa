*** Settings ***
Library           RequestsLibrary
Library           Collections
Resource          ../../resources/common.resource
Variables         ../../resources/variables/default.yaml

Suite Setup       Verify API Is Up

*** Test Cases ***
List All Books Returns Non-Empty List
    [Tags]    books    smoke    critical
    [Documentation]    GET /books returns 200 and a non-empty JSON array.
    ${resp}=    GET    ${BASE_URL}/books    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    ${books}=    Set Variable    ${resp.json()}
    Should Not Be Empty    ${books}

Filter Books By Fiction Type
    [Tags]    books    regression
    [Documentation]    GET /books?type=fiction returns only fiction books.
    ${resp}=    GET    ${BASE_URL}/books    params=type=fiction    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    FOR    ${book}    IN    @{resp.json()}
        Should Be Equal    ${book}[type]    fiction
    END

Filter Books By Non-Fiction Type
    [Tags]    books    regression
    [Documentation]    GET /books?type=non-fiction returns only non-fiction books.
    ${resp}=    GET    ${BASE_URL}/books    params=type=non-fiction    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    FOR    ${book}    IN    @{resp.json()}
        Should Be Equal    ${book}[type]    non-fiction
    END

Get Single Book Returns Correct Fields
    [Tags]    books    smoke
    [Documentation]    GET /books/1 returns a book object with required fields.
    ${resp}=    GET    ${BASE_URL}/books/1    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    ${book}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${book}    id
    Dictionary Should Contain Key    ${book}    name
    Dictionary Should Contain Key    ${book}    type
    Dictionary Should Contain Key    ${book}    available

Get Non-Existent Book Returns 404
    [Tags]    books    regression
    [Documentation]    GET /books/99999 returns 404 Not Found.
    ${resp}=    GET    ${BASE_URL}/books/99999    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    404
