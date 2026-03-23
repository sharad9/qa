# Bookstore QA Platform — Design Spec

**Date:** 2026-03-23
**Status:** Approved
**Author:** Claude Code (brainstorming session)

---

## Overview

A self-contained sample QA platform demonstrating a production-grade test pipeline for a Bookstore REST API. The target application is the publicly available [Simple Books API](https://simple-books-api.glitch.me) — no local backend required.

The project showcases the full four-tool integration:
- **Robot Framework** — test authoring and execution
- **Kiwi TCMS** — test management dashboard at `vitals.visithealth.ai`
- **GitHub Actions** — CI orchestration with parallel domain jobs
- **Allure** — per-run detailed HTML reports published to GitHub Pages

---

## Architecture

### Folder Structure

```
bookstore-qa/
├── tests/
│   ├── auth/               # API token generation & validation
│   │   └── auth_tests.robot
│   ├── books/              # List, get, filter books
│   │   └── books_tests.robot
│   └── orders/             # Place, retrieve, delete orders
│       └── orders_tests.robot
├── resources/
│   ├── common.resource     # Shared keywords (setup/teardown, logging)
│   ├── auth.resource       # Auth-specific keywords (get token, store token)
│   └── variables/
│       └── default.yaml    # Base URL, timeouts, test data
├── infra/
│   ├── docker-compose.yml  # Kiwi TCMS + PostgreSQL + nginx
│   └── deploy.sh           # Bootstrap script for Kiwi TCMS instance
├── .github/
│   └── workflows/
│       └── qa.yml          # Parallel CI jobs + Allure merge + GH Pages publish
├── results/                # Gitignored — Allure output lands here locally
├── requirements.txt
└── README.md
```

---

## Components

### 1. Test Suites (Robot Framework)

Three domain-separated suites under `tests/`:

| Suite | Covers | Key test cases |
|-------|--------|----------------|
| `auth/` | Token lifecycle | Register client, get access token, token required error |
| `books/` | Book catalogue | List all books, get single book, filter by type (fiction/non-fiction) |
| `orders/` | Order management | Place order, get order, update order, delete order |

Each `.robot` file follows:
- `*** Settings ***` — imports `common.resource`, `auth.resource` as needed
- `*** Variables ***` — suite-local overrides (if any)
- `*** Test Cases ***` — named, tagged test cases
- `*** Keywords ***` — suite-local helper keywords

Tags used: `smoke`, `regression`, `auth`, `books`, `orders`, `critical`

### 2. Resources

- **`common.resource`** — `Log Response`, `Verify Status Code`, `Suite Setup`/`Suite Teardown` hooks
- **`auth.resource`** — `Get Access Token` keyword that POSTs to `/api-clients/` and caches the token as a suite variable
- **`variables/default.yaml`** — `BASE_URL`, `TIMEOUT`, `CLIENT_NAME`, `CLIENT_EMAIL`

### 3. Kiwi TCMS Integration

Uses the `kiwitcms-robotframework-plugin` listener. On each run the listener:
1. Looks up (or creates) the Product, Version, Build, TestPlan, and TestRun
2. Maps each Robot Framework test case to a Kiwi TCMS TestCase by name
3. Records PASS/FAIL status on the TestRun in real time

Environment variables required:
```
TCMS_API_URL=https://vitals.visithealth.ai/json-rpc/
TCMS_USERNAME=<secret>
TCMS_PASSWORD=<secret>
TCMS_PRODUCT=Bookstore
TCMS_PRODUCT_VERSION=v1
TCMS_BUILD=$GITHUB_SHA (short)
TCMS_PLAN_NAME=Regression
```

Invocation:
```bash
robot --listener kiwitcms_robotframework.Listener tests/
```

### 4. Allure Reporting

Uses the `allure-robotframework` listener. Produces raw Allure results (JSON) to `results/allure-results/`.

Post-run, `allure generate` converts them to an HTML report in `results/allure-report/`.

GitHub Actions publishes the merged report from all three domain jobs to GitHub Pages on every run.

### 5. GitHub Actions Workflow

File: `.github/workflows/qa.yml`

```
Trigger: push to main, pull_request

Jobs:
  test-auth    — runs tests/auth/
  test-books   — runs tests/books/
  test-orders  — runs tests/orders/   (depends on test-auth for token setup)

  publish-report:
    needs: [test-auth, test-books, test-orders]
    steps:
      - download all allure-results artifacts
      - merge into single allure-results/
      - allure generate → allure-report/
      - deploy to GitHub Pages (peaceiris/actions-gh-pages)
```

Each test job:
1. Checks out the repo
2. Sets up Python + installs `requirements.txt`
3. Runs `robot` with both the Kiwi TCMS and Allure listeners
4. Uploads `allure-results/` as a GitHub Actions artifact

### 6. Kiwi TCMS Infrastructure (`infra/`)

Docker Compose runs:
- `kiwitcms/kiwi` — the web application
- `postgres:15` — database
- `nginx` — TLS termination proxy

`deploy.sh` is a convenience wrapper that pulls images, runs migrations, and creates the superuser on first boot.

---

## Data Flow

```
Robot Framework run
  ├─► kiwitcms listener  ─► Kiwi TCMS (live test run updates)
  └─► allure listener    ─► allure-results/ (JSON)
                                  │
                            allure generate
                                  │
                            allure-report/ (HTML)
                                  │
                           GitHub Pages publish
```

---

## Error Handling

- Tests use `expected_status=any` on HTTP calls and assert status codes explicitly — no test crashes on unexpected HTTP errors.
- `Suite Setup` verifies the API base URL is reachable; if not, the entire suite is skipped with a clear message rather than failing every test individually.
- Kiwi TCMS listener failures are non-fatal — the RF run continues even if TCMS reporting is unavailable (controlled by `--listener` being optional in local runs).

---

## Testing the Platform Itself

A `tests/vitals/` suite (self-tests) verifies:
- Kiwi TCMS web interface is reachable
- Kiwi TCMS JSON-RPC endpoint accepts requests
- Robot Framework version matches requirements

---

## Requirements

```
robotframework==6.1.1
robotframework-requests>=0.9
kiwitcms-robotframework-plugin>=12.0
allure-robotframework>=2.13
PyYAML>=6.0
```

---

## Success Criteria

1. `robot tests/books/` runs locally and all tests pass against Simple Books API
2. A GitHub Actions push triggers all three domain jobs in parallel
3. Allure report is published to GitHub Pages after every run
4. Kiwi TCMS reflects the latest test run results at `vitals.visithealth.ai`
5. A new contributor can add a test case in under 5 minutes by following the README
