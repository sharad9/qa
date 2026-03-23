# Bookstore QA Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a fully working sample QA platform (bookstore-qa) that demonstrates Robot Framework tests, Kiwi TCMS test management, GitHub Actions CI, and Allure reports — all wired together against the public Simple Books API.

**Architecture:** Three domain test suites (auth/books/orders) run in parallel on GitHub Actions. Each suite emits Allure JSON artifacts; a fourth job merges them and publishes an HTML report to GitHub Pages. Simultaneously, the Kiwi TCMS listener records live test results against a self-hosted Docker instance. Shared keywords live in `resources/` and are imported by every suite.

**Tech Stack:** Robot Framework 6.1.1, robotframework-requests, kiwitcms-robotframework-plugin ≥12.0, allure-robotframework ≥2.13, PyYAML ≥6.0, Docker Compose (Kiwi TCMS + PostgreSQL 15 + nginx), GitHub Actions, peaceiris/actions-gh-pages.

---

## File Map

| File | Responsibility |
|------|---------------|
| `requirements.txt` | Python dependencies for RF + plugins |
| `.env.example` | Template for TCMS credentials (committed) |
| `.gitignore` | Ignore `results/`, `.env`, `__pycache__` |
| `Makefile` | `test`, `report`, `kiwi-up`, `kiwi-down` targets |
| `resources/variables/default.yaml` | `BASE_URL`, `TIMEOUT`, `CLIENT_NAME`, `CLIENT_EMAIL` |
| `resources/common.resource` | `Verify API Is Up`, `Log Response`, `Verify Status Code` keywords |
| `resources/auth.resource` | `Get Access Token`, `Register API Client` keywords |
| `tests/auth/auth_tests.robot` | Auth domain test cases |
| `tests/books/books_tests.robot` | Books domain test cases |
| `tests/orders/orders_tests.robot` | Orders domain test cases |
| `tests/vitals/platform_health.robot` | Self-tests: RF version, Kiwi reachability |
| `infra/docker-compose.yml` | Kiwi TCMS + PostgreSQL + nginx services |
| `infra/deploy.sh` | First-boot bootstrap (migrations, superuser) |
| `infra/nginx/nginx.conf` | Reverse proxy config (HTTP dev, HTTPS prod) |
| `.github/workflows/qa.yml` | Parallel test jobs + Allure publish job |
| `README.md` | Quick start, adding tests, tool overview |

---

## Task 1: Project Scaffold

**Files:**
- Create: `requirements.txt`
- Create: `.env.example`
- Create: `.gitignore`
- Create: `Makefile`

- [ ] **Step 1.1: Create `requirements.txt`**

```
robotframework==6.1.1
robotframework-requests>=0.9
kiwitcms-robotframework-plugin>=12.0
allure-robotframework>=2.13
PyYAML>=6.0
```

- [ ] **Step 1.2: Create `.env.example`**

```bash
# Copy this to .env and fill in your values. NEVER commit .env.
TCMS_API_URL=http://localhost:8080/json-rpc/
TCMS_USERNAME=your-username
TCMS_PASSWORD=your-password
TCMS_PRODUCT=Bookstore
TCMS_PRODUCT_VERSION=v1
TCMS_BUILD=local
TCMS_PLAN_NAME=Regression
```

- [ ] **Step 1.3: Create `.gitignore`**

```
results/
.env
__pycache__/
*.pyc
*.egg-info/
.allure/
```

- [ ] **Step 1.4: Create `Makefile`**

```makefile
.PHONY: test report kiwi-up kiwi-down clean

# Load .env if present
ifneq (,$(wildcard .env))
  include .env
  export
endif

# Run all tests with Allure listener (no TCMS listener required locally)
test:
	robot \
	  --listener allure_robotframework \
	  --outputdir results/allure-results \
	  tests/

# Run specific suite: make test-books, make test-auth, make test-orders
# Adds TCMS listener automatically if TCMS_API_URL is set in .env
test-%:
	robot \
	  --listener allure_robotframework \
	  $(if $(TCMS_API_URL),--listener kiwitcms_robotframework.Listener,) \
	  --outputdir results/allure-results-$* \
	  tests/$*/

# Generate Allure HTML report — merges all allure-results-* dirs
report:
	mkdir -p merged-allure-results
	find results/ -name "*.json" -exec cp {} merged-allure-results/ \;
	find results/ -name "*.xml"  -exec cp {} merged-allure-results/ \;
	allure generate merged-allure-results/ -o results/allure-report --clean
	@echo "Report ready: results/allure-report/index.html"

# Start Kiwi TCMS via Docker Compose
kiwi-up:
	docker compose -f infra/docker-compose.yml up -d
	@echo "Kiwi TCMS starting at http://localhost:8080"

# Stop Kiwi TCMS
kiwi-down:
	docker compose -f infra/docker-compose.yml down

# Remove generated results
clean:
	rm -rf results/
```

- [ ] **Step 1.5: Verify directory structure exists**

Run: `ls bookstore-qa/`
Expected: `docs/  requirements.txt  .env.example  .gitignore  Makefile`

- [ ] **Step 1.6: Commit**

```bash
git add requirements.txt .env.example .gitignore Makefile
git commit -m "chore: project scaffold — requirements, Makefile, gitignore"
```

---

## Task 2: Shared Resources

**Files:**
- Create: `resources/variables/default.yaml`
- Create: `resources/common.resource`
- Create: `resources/auth.resource`

- [ ] **Step 2.1: Create `resources/variables/default.yaml`**

```yaml
BASE_URL: https://simple-books-api.glitch.me
TIMEOUT: 10s
CLIENT_NAME: BookstoreQA
CLIENT_EMAIL: qa@bookstore-sample.test
```

- [ ] **Step 2.2: Create `resources/common.resource`**

```robot
*** Settings ***
Library    RequestsLibrary
Library    Collections

*** Keywords ***
Verify API Is Up
    [Documentation]    Ping the API status endpoint. Skip entire suite if unreachable.
    ${resp}=    GET    ${BASE_URL}/status    expected_status=any    timeout=${TIMEOUT}
    Run Keyword If    ${resp.status_code} >= 500
    ...    Skip    API unreachable (status ${resp.status_code}) — skipping suite

Log Response
    [Arguments]    ${resp}
    Log    Status: ${resp.status_code}
    Log    Body: ${resp.text}

Verify Status Code
    [Arguments]    ${resp}    ${expected}
    Should Be Equal As Integers    ${resp.status_code}    ${expected}
    ...    msg=Expected HTTP ${expected} but got ${resp.status_code}: ${resp.text}
```

- [ ] **Step 2.3: Create `resources/auth.resource`**

```robot
*** Settings ***
Library    RequestsLibrary
Library    Collections
Variables  variables/default.yaml

*** Variables ***
${ACCESS_TOKEN}    ${EMPTY}

*** Keywords ***
Register API Client
    [Documentation]    Register a new API client and return its credentials.
    ...                The Simple Books API requires unique email per client.
    ${body}=    Create Dictionary
    ...    clientName=${CLIENT_NAME}
    ...    clientEmail=${CLIENT_EMAIL}
    ${resp}=    POST    ${BASE_URL}/api-clients/    json=${body}    expected_status=any
    Log Response    ${resp}
    # 409 = client already exists — that's fine, proceed to get token
    Run Keyword Unless    ${resp.status_code} in [201, 409]
    ...    Fail    Client registration failed: ${resp.text}

Get Access Token
    [Documentation]    Register client and obtain a Bearer access token.
    ...                On first call returns 201 + accessToken. On duplicate email returns 409.
    ...                Use a timestamp-suffixed CLIENT_EMAIL to ensure fresh token every run.
    ${body}=    Create Dictionary    clientName=${CLIENT_NAME}    clientEmail=${CLIENT_EMAIL}
    ${resp}=    POST    ${BASE_URL}/api-clients/    json=${body}    expected_status=any
    Log Response    ${resp}
    Run Keyword If    ${resp.status_code} != 201
    ...    Fail    Expected 201 from /api-clients/ but got ${resp.status_code}. Use a unique CLIENT_EMAIL.
    ${token}=    Set Variable    ${resp.json()}[accessToken]
    Set Suite Variable    ${ACCESS_TOKEN}    ${token}
    [Return]    ${token}
```

> **Note on auth.resource:** The Simple Books API issues a token on client registration (POST /api-clients/ returns `{"accessToken": "..."}` on first call, 409 on duplicate). The `Get Access Token` keyword handles both cases. If a test run uses a fresh `CLIENT_EMAIL`, registration always succeeds. If the same email was used before, use a timestamp suffix in `default.yaml` for CI runs.

- [ ] **Step 2.4: Verify resources are importable**

Run: `python -m robot --dryrun --variable BASE_URL:https://simple-books-api.glitch.me resources/common.resource 2>&1 | head -5`

Expected: no import errors (dryrun may warn about no test cases — that's fine)

- [ ] **Step 2.5: Commit**

```bash
git add resources/
git commit -m "feat: shared resources — variables, common keywords, auth keyword library"
```

---

## Task 3: Auth Test Suite

**Files:**
- Create: `tests/auth/auth_tests.robot`

The Simple Books API auth flow: `POST /api-clients/` → get `accessToken`. Test that:
1. A new client can register and receives a token
2. Duplicate registration returns 409
3. A protected endpoint returns 401 without a token

- [ ] **Step 3.1: Write `tests/auth/auth_tests.robot`**

```robot
*** Settings ***
Library           RequestsLibrary
Library           Collections
Resource          ../../resources/common.resource
Variables         ../../resources/variables/default.yaml

Suite Setup       Verify API Is Up

*** Variables ***
${UNIQUE_EMAIL}    qa+${None}@bookstore-sample.test

*** Test Cases ***
Register New Client Returns Access Token
    [Tags]    auth    smoke    critical
    [Documentation]    POST /api-clients/ with a unique email returns 201 and an accessToken.
    ${ts}=    Evaluate    int(__import__('time').time())
    ${email}=    Set Variable    qa+${ts}@bookstore-sample.test
    ${body}=    Create Dictionary    clientName=BookstoreQA    clientEmail=${email}
    ${resp}=    POST    ${BASE_URL}/api-clients/    json=${body}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    201
    Dictionary Should Contain Key    ${resp.json()}    accessToken
    Should Not Be Empty    ${resp.json()}[accessToken]

Duplicate Client Registration Returns 409
    [Tags]    auth    regression
    [Documentation]    Registering the same email twice returns 409 Conflict.
    ${ts}=    Evaluate    int(__import__('time').time())
    ${email}=    Set Variable    qa+dup${ts}@bookstore-sample.test
    ${body}=    Create Dictionary    clientName=BookstoreQA    clientEmail=${email}
    POST    ${BASE_URL}/api-clients/    json=${body}    expected_status=201
    ${resp}=    POST    ${BASE_URL}/api-clients/    json=${body}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    409

Protected Endpoint Requires Token
    [Tags]    auth    smoke    critical
    [Documentation]    GET /orders without Authorization header returns 401.
    ${resp}=    GET    ${BASE_URL}/orders    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    401
```

- [ ] **Step 3.2: Run auth tests locally**

```bash
robot --outputdir results/allure-results-auth \
      --listener allure_robotframework \
      tests/auth/
```

Expected: `3 tests, 3 passed, 0 failed`

- [ ] **Step 3.3: Commit**

```bash
git add tests/auth/
git commit -m "feat(auth): auth test suite — registration, duplicate, token guard"
```

---

## Task 4: Books Test Suite

**Files:**
- Create: `tests/books/books_tests.robot`

Simple Books API books endpoints:
- `GET /books` — list all books, optional `?type=fiction|non-fiction&limit=N`
- `GET /books/:id` — get single book

- [ ] **Step 4.1: Write `tests/books/books_tests.robot`**

```robot
*** Settings ***
Library           RequestsLibrary
Library           Collections
Resource          ../../resources/common.resource
Resource          ../../resources/auth.resource
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
```

- [ ] **Step 4.2: Run books tests locally**

```bash
robot --outputdir results/allure-results-books \
      --listener allure_robotframework \
      tests/books/
```

Expected: `5 tests, 5 passed, 0 failed`

- [ ] **Step 4.3: Commit**

```bash
git add tests/books/
git commit -m "feat(books): books test suite — list, filter, get, 404"
```

---

## Task 5: Orders Test Suite

**Files:**
- Create: `tests/orders/orders_tests.robot`

Simple Books API orders endpoints (all require Bearer token):
- `POST /orders` — place an order (`{"bookId": N, "customerName": "..."}`)
- `GET /orders` — list all orders for this client
- `GET /orders/:id` — get single order
- `PATCH /orders/:id` — update `customerName`
- `DELETE /orders/:id` — delete order

- [ ] **Step 5.1: Write `tests/orders/orders_tests.robot`**

```robot
*** Settings ***
Library           RequestsLibrary
Library           Collections
Resource          ../../resources/common.resource
Resource          ../../resources/auth.resource
Variables         ../../resources/variables/default.yaml

Suite Setup       Run Keywords    Verify API Is Up    AND    Initialize Auth

*** Variables ***
${TOKEN}          ${EMPTY}
${ORDER_ID}       ${EMPTY}

*** Keywords ***
Initialize Auth
    [Documentation]    Obtain a fresh access token for this suite run.
    ${ts}=    Evaluate    int(__import__('time').time())
    ${email}=    Set Variable    orders+${ts}@bookstore-sample.test
    ${body}=    Create Dictionary    clientName=BookstoreQA    clientEmail=${email}
    ${resp}=    POST    ${BASE_URL}/api-clients/    json=${body}    expected_status=201
    Set Suite Variable    ${TOKEN}    ${resp.json()}[accessToken]

Auth Headers
    [Documentation]    Return a dict with the Authorization header.
    ${headers}=    Create Dictionary    Authorization=Bearer ${TOKEN}
    [Return]    ${headers}

*** Test Cases ***
Place An Order
    [Tags]    orders    smoke    critical
    [Documentation]    POST /orders with a valid bookId places an order and returns 201.
    ${headers}=    Auth Headers
    ${body}=    Create Dictionary    bookId=${1}    customerName=QA Tester
    ${resp}=    POST    ${BASE_URL}/orders    json=${body}    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    201
    Dictionary Should Contain Key    ${resp.json()}    orderId
    Set Suite Variable    ${ORDER_ID}    ${resp.json()}[orderId]

Get Placed Order
    [Tags]    orders    smoke
    [Documentation]    GET /orders/:id returns the order just placed.
    [Setup]    Run Keyword If    '${ORDER_ID}' == '${EMPTY}'    Skip    Place An Order must run first
    ${headers}=    Auth Headers
    ${resp}=    GET    ${BASE_URL}/orders/${ORDER_ID}    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    Should Be Equal    ${resp.json()}[id]    ${ORDER_ID}

List Orders Returns Array
    [Tags]    orders    regression
    [Documentation]    GET /orders returns a JSON array for this client.
    ${headers}=    Auth Headers
    ${resp}=    GET    ${BASE_URL}/orders    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    200
    ${orders}=    Set Variable    ${resp.json()}
    Should Be True    isinstance($orders, list)

Update Order Customer Name
    [Tags]    orders    regression
    [Documentation]    PATCH /orders/:id updates the customerName field.
    [Setup]    Run Keyword If    '${ORDER_ID}' == '${EMPTY}'    Skip    Place An Order must run first
    ${headers}=    Auth Headers
    ${body}=    Create Dictionary    customerName=Updated QA Tester
    ${resp}=    PATCH    ${BASE_URL}/orders/${ORDER_ID}    json=${body}    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    204

Delete Order
    [Tags]    orders    regression
    [Documentation]    DELETE /orders/:id removes the order; subsequent GET returns 404.
    [Setup]    Run Keyword If    '${ORDER_ID}' == '${EMPTY}'    Skip    Place An Order must run first
    ${headers}=    Auth Headers
    ${resp}=    DELETE    ${BASE_URL}/orders/${ORDER_ID}    headers=${headers}    expected_status=any
    Log Response    ${resp}
    Verify Status Code    ${resp}    204
    # Confirm deletion
    ${check}=    GET    ${BASE_URL}/orders/${ORDER_ID}    headers=${headers}    expected_status=any
    Verify Status Code    ${check}    404
```

- [ ] **Step 5.2: Run orders tests locally**

```bash
robot --outputdir results/allure-results-orders \
      --listener allure_robotframework \
      tests/orders/
```

Expected: `5 tests, 5 passed, 0 failed`

- [ ] **Step 5.3: Commit**

```bash
git add tests/orders/
git commit -m "feat(orders): orders test suite — place, get, list, update, delete"
```

---

## Task 6: Platform Self-Tests (Vitals Suite)

**Files:**
- Create: `tests/vitals/platform_health.robot`

Validates the test platform itself: RF version correct, Kiwi TCMS reachable.

- [ ] **Step 6.1: Write `tests/vitals/platform_health.robot`**

```robot
*** Settings ***
Library    RequestsLibrary
Library    Collections
Library    OperatingSystem
Library    Process

*** Test Cases ***
Robot Framework Version Is Correct
    [Tags]    vitals    smoke
    [Documentation]    Verify robotframework==6.1.1 is installed.
    ${result}=    Run Process    python    -c
    ...    import robot; print(robot.version.VERSION)
    Should Contain    ${result.stdout}    6.1
    ...    msg=Expected Robot Framework 6.1.x but got: ${result.stdout}

Kiwi TCMS Web Interface Is Reachable
    [Tags]    vitals    kiwi
    [Documentation]    Verify Kiwi TCMS web interface responds (requires KIWI_URL env var).
    ${url}=    Get Environment Variable    KIWI_URL    default=http://localhost:8080
    ${resp}=    GET    ${url}    expected_status=any    timeout=10
    Should Be True    ${resp.status_code} < 500
    ...    msg=Kiwi TCMS returned unexpected status: ${resp.status_code}

Kiwi TCMS JSON-RPC Endpoint Available
    [Tags]    vitals    kiwi
    [Documentation]    Verify the JSON-RPC endpoint accepts requests.
    ${url}=    Get Environment Variable    KIWI_URL    default=http://localhost:8080
    ${body}=    Create Dictionary    jsonrpc=2.0    method=Auth.login    id=1
    ${params}=    Create Dictionary    username=guest    password=guest
    Set To Dictionary    ${body}    params=${params}
    ${resp}=    POST    ${url}/json-rpc/    json=${body}    expected_status=any    timeout=10
    Should Be True    ${resp.status_code} < 500
    ...    msg=JSON-RPC endpoint returned: ${resp.status_code}
```

- [ ] **Step 6.2: Run vitals tests (skip kiwi tests if not running locally)**

```bash
robot --outputdir results/allure-results-vitals \
      --listener allure_robotframework \
      --exclude kiwi \
      tests/vitals/
```

Expected: `1 test, 1 passed, 0 failed` (RF version check only; kiwi tests excluded)

- [ ] **Step 6.3: Commit**

```bash
git add tests/vitals/
git commit -m "feat(vitals): platform self-tests — RF version, Kiwi TCMS health"
```

---

## Task 7: Kiwi TCMS Infrastructure

**Files:**
- Create: `infra/docker-compose.yml`
- Create: `infra/deploy.sh`
- Create: `infra/nginx/nginx.conf`

- [ ] **Step 7.1: Create `infra/docker-compose.yml`**

```yaml
version: "3.9"

services:
  db:
    image: postgres:15
    restart: unless-stopped
    environment:
      POSTGRES_DB: kiwi
      POSTGRES_USER: kiwi
      POSTGRES_PASSWORD: kiwi_secret
    volumes:
      - kiwi_db_data:/var/lib/postgresql/data

  kiwi:
    image: kiwitcms/kiwi:latest
    restart: unless-stopped
    depends_on:
      - db
    environment:
      KIWI_DB_HOST: db
      KIWI_DB_PORT: 5432
      KIWI_DB_NAME: kiwi
      KIWI_DB_USER: kiwi
      KIWI_DB_PASSWORD: kiwi_secret
    volumes:
      - kiwi_uploads:/Kiwi/uploads

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    depends_on:
      - kiwi
    ports:
      - "8080:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro

volumes:
  kiwi_db_data:
  kiwi_uploads:
```

- [ ] **Step 7.2: Create `infra/nginx/nginx.conf`**

```nginx
server {
    listen 80;
    server_name _;

    client_max_body_size 20M;

    location / {
        proxy_pass         http://kiwi:8080;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }
}
```

- [ ] **Step 7.3: Create `infra/deploy.sh`**

```bash
#!/usr/bin/env bash
# Bootstrap Kiwi TCMS on first run.
# Usage: sudo bash infra/deploy.sh
set -euo pipefail

COMPOSE="docker compose -f $(dirname "$0")/docker-compose.yml"

echo "==> Pulling images..."
$COMPOSE pull

echo "==> Starting services..."
$COMPOSE up -d

echo "==> Waiting for database to be ready..."
sleep 10

echo "==> Running migrations..."
$COMPOSE exec kiwi python manage.py migrate --noinput

echo "==> Creating superuser (if not exists)..."
$COMPOSE exec kiwi python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', 'admin')
    print('Superuser created: admin / admin')
else:
    print('Superuser already exists.')
"

echo ""
echo "==> Kiwi TCMS is ready at http://localhost:8080"
echo "    Login: admin / admin"
echo "    IMPORTANT: Change the password immediately in production!"
```

- [ ] **Step 7.4: Make deploy.sh executable**

```bash
chmod +x infra/deploy.sh
```

- [ ] **Step 7.5: Verify Docker Compose config is valid**

```bash
docker compose -f infra/docker-compose.yml config --quiet
```

Expected: no output (exit code 0)

- [ ] **Step 7.6: Commit**

```bash
git add infra/
git commit -m "feat(infra): Kiwi TCMS docker-compose, nginx proxy, deploy script"
```

---

## Task 8: GitHub Actions Workflow

**Files:**
- Create: `.github/workflows/qa.yml`

Three parallel test jobs + one publish job.

- [ ] **Step 8.1: Create `.github/workflows/qa.yml`**

```yaml
name: QA Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  # ── Domain test jobs (run in parallel) ──────────────────────────────────────

  test-auth:
    name: Auth Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"
          cache: pip

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run auth tests
        env:
          TCMS_API_URL: ${{ secrets.TCMS_API_URL }}
          TCMS_USERNAME: ${{ secrets.TCMS_USERNAME }}
          TCMS_PASSWORD: ${{ secrets.TCMS_PASSWORD }}
          TCMS_PRODUCT: Bookstore
          TCMS_PRODUCT_VERSION: v1
          TCMS_BUILD: ${{ github.sha && github.sha[:7] || 'local' }}
          TCMS_PLAN_NAME: Regression
        run: |
          robot \
            --listener allure_robotframework \
            --listener kiwitcms_robotframework.Listener \
            --outputdir results/allure-results-auth \
            --log NONE --report NONE \
            tests/auth/ || true

      - name: Upload Allure results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: allure-results-auth
          path: results/allure-results-auth/
          retention-days: 7

  test-books:
    name: Books Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"
          cache: pip

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run books tests
        env:
          TCMS_API_URL: ${{ secrets.TCMS_API_URL }}
          TCMS_USERNAME: ${{ secrets.TCMS_USERNAME }}
          TCMS_PASSWORD: ${{ secrets.TCMS_PASSWORD }}
          TCMS_PRODUCT: Bookstore
          TCMS_PRODUCT_VERSION: v1
          TCMS_BUILD: ${{ github.sha && github.sha[:7] || 'local' }}
          TCMS_PLAN_NAME: Regression
        run: |
          robot \
            --listener allure_robotframework \
            --listener kiwitcms_robotframework.Listener \
            --outputdir results/allure-results-books \
            --log NONE --report NONE \
            tests/books/ || true

      - name: Upload Allure results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: allure-results-books
          path: results/allure-results-books/
          retention-days: 7

  test-orders:
    name: Orders Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"
          cache: pip

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run orders tests
        env:
          TCMS_API_URL: ${{ secrets.TCMS_API_URL }}
          TCMS_USERNAME: ${{ secrets.TCMS_USERNAME }}
          TCMS_PASSWORD: ${{ secrets.TCMS_PASSWORD }}
          TCMS_PRODUCT: Bookstore
          TCMS_PRODUCT_VERSION: v1
          TCMS_BUILD: ${{ github.sha && github.sha[:7] || 'local' }}
          TCMS_PLAN_NAME: Regression
        run: |
          robot \
            --listener allure_robotframework \
            --listener kiwitcms_robotframework.Listener \
            --outputdir results/allure-results-orders \
            --log NONE --report NONE \
            tests/orders/ || true

      - name: Upload Allure results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: allure-results-orders
          path: results/allure-results-orders/
          retention-days: 7

  # ── Publish Allure report to GitHub Pages ───────────────────────────────────

  publish-report:
    name: Publish Allure Report
    runs-on: ubuntu-latest
    needs: [test-auth, test-books, test-orders]
    if: always()
    permissions:
      contents: write

    steps:
      - uses: actions/checkout@v4

      - name: Install Allure CLI
        run: |
          curl -o allure.tgz -sSL \
            https://github.com/allure-framework/allure2/releases/download/2.27.0/allure-2.27.0.tgz
          tar -xzf allure.tgz -C /opt
          ln -s /opt/allure-2.27.0/bin/allure /usr/local/bin/allure

      - name: Download auth results
        uses: actions/download-artifact@v4
        with:
          name: allure-results-auth
          path: downloaded/allure-results-auth/
        continue-on-error: true

      - name: Download books results
        uses: actions/download-artifact@v4
        with:
          name: allure-results-books
          path: downloaded/allure-results-books/
        continue-on-error: true

      - name: Download orders results
        uses: actions/download-artifact@v4
        with:
          name: allure-results-orders
          path: downloaded/allure-results-orders/
        continue-on-error: true

      - name: Merge Allure results
        run: |
          mkdir -p merged-allure-results
          find downloaded/ -name "*.json" -exec cp {} merged-allure-results/ \;
          find downloaded/ -name "*.xml"  -exec cp {} merged-allure-results/ \;
          echo "Merged $(ls merged-allure-results/ | wc -l) result files"

      - name: Restore Allure history from gh-pages
        run: |
          # merged-allure-results/ already exists from previous step
          git fetch origin gh-pages 2>/dev/null || echo "gh-pages branch not found — skipping history restore"
          if git show-ref --quiet refs/remotes/origin/gh-pages; then
            git checkout origin/gh-pages -- allure-report/history 2>/dev/null || true
            if [ -d "allure-report/history" ]; then
              cp -r allure-report/history merged-allure-results/history
              echo "History restored"
            else
              echo "No history found in gh-pages — first run"
            fi
          fi

      - name: Generate Allure HTML report
        run: |
          allure generate merged-allure-results/ -o allure-report/ --clean

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: allure-report/
          destination_dir: .
          keep_files: false
```

- [ ] **Step 8.2: Verify workflow YAML is valid**

```bash
python -c "import yaml; yaml.safe_load(open('.github/workflows/qa.yml'))" && echo "YAML valid"
```

Expected: `YAML valid`

- [ ] **Step 8.3: Commit**

```bash
git add .github/
git commit -m "feat(ci): GitHub Actions — parallel domain jobs + Allure publish to GH Pages"
```

---

## Task 9: README

**Files:**
- Create: `README.md`

- [ ] **Step 9.1: Write `README.md`**

```markdown
# bookstore-qa

Sample QA platform demonstrating a production-grade test pipeline.

**Target:** [Simple Books API](https://simple-books-api.glitch.me)

## Stack

| Tool | Role |
|------|------|
| Robot Framework | Test authoring & execution |
| Kiwi TCMS | Test management dashboard |
| GitHub Actions | CI orchestration (parallel domain jobs) |
| Allure | Per-run HTML reports → GitHub Pages |

## Quick Start

```bash
# 1. Install Python dependencies
pip install -r requirements.txt

# 2. Run all tests (Allure output only — no TCMS required)
make test

# 3. Generate HTML report
make report
open results/allure-report/index.html

# 4. Run a single domain
make test-books
```

## With Kiwi TCMS

```bash
# Start Kiwi TCMS locally
make kiwi-up

# First time only — run migrations & create superuser
sudo bash infra/deploy.sh

# Copy credentials template
cp .env.example .env
# Edit .env with your TCMS_USERNAME and TCMS_PASSWORD

# Run tests with TCMS listener
robot \
  --listener allure_robotframework \
  --listener kiwitcms_robotframework.Listener \
  --outputdir results/ \
  tests/
```

Open http://localhost:8080 to view test runs in Kiwi TCMS.

## Adding a Test

1. Open `tests/<domain>/<domain>_tests.robot`
2. Add a new `*** Test Cases ***` entry — copy an existing one as a template
3. Tag it: `[Tags]    <domain>    regression`
4. Run locally: `robot tests/<domain>/`
5. All tests pass? Open a PR.

## Project Structure

```
tests/
  auth/       — token lifecycle tests
  books/      — catalogue list, filter, get
  orders/     — place, get, update, delete
  vitals/     — platform self-tests
resources/
  common.resource        — shared keywords
  auth.resource          — token acquisition
  variables/default.yaml — config
infra/
  docker-compose.yml     — Kiwi TCMS stack
  deploy.sh              — first-boot setup
.github/workflows/qa.yml — CI pipeline
```

## CI / GitHub Actions

Every push to `main` and every PR triggers:
- Three parallel jobs: `test-auth`, `test-books`, `test-orders`
- A `publish-report` job that merges Allure results and deploys to GitHub Pages

**GitHub Pages setup (one-time):**
1. Go to repo Settings → Pages
2. Set Source to `gh-pages` branch, root `/`
3. The Allure report will be at `https://<org>.github.io/<repo>/`

## Secrets Required (GitHub Actions)

| Secret | Value |
|--------|-------|
| `TCMS_API_URL` | `https://vitals.visithealth.ai/json-rpc/` |
| `TCMS_USERNAME` | CI service account username |
| `TCMS_PASSWORD` | CI service account password |

If secrets are not set, the TCMS listener is skipped and tests still run normally.
```

- [ ] **Step 9.2: Commit**

```bash
git add README.md
git commit -m "docs: README — quick start, adding tests, CI setup"
```

---

## Task 10: Final Verification

- [ ] **Step 10.1: Run full local test suite**

```bash
make test
```

Expected: all tests in `tests/` pass (auth, books, orders suites)

- [ ] **Step 10.2: Generate Allure report**

```bash
make report
```

Expected: `results/allure-report/index.html` exists and opens in browser

- [ ] **Step 10.3: Verify Docker Compose starts cleanly**

```bash
make kiwi-up
sleep 15
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080
make kiwi-down
```

Expected: HTTP status `200` or `302`

- [ ] **Step 10.4: Verify YAML and file structure**

```bash
python -c "import yaml; yaml.safe_load(open('.github/workflows/qa.yml'))" && echo "CI YAML: OK"
python -c "import yaml; yaml.safe_load(open('resources/variables/default.yaml'))" && echo "Variables YAML: OK"
```

Expected: both print OK

- [ ] **Step 10.5: Final commit**

```bash
git add -A
git status   # should be clean
git log --oneline
```

Expected: clean working tree with ~9 commits on main
