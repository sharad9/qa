# Bookstore QA Platform — Design Spec

**Date:** 2026-03-23
**Status:** Approved
**Author:** Claude Code (brainstorming session)

---

## Overview

A self-contained sample QA platform demonstrating a production-grade test pipeline for a Bookstore REST API. The target application is the publicly available [Simple Books API](https://simple-books-api.glitch.me) — no local backend required.

The project showcases the full four-tool integration:
- **Robot Framework** — test authoring and execution
- **Kiwi TCMS** — test management dashboard, self-hosted via Docker Compose (configurable URL, defaults to `http://localhost:8080`; in production deploy at `vitals.visithealth.ai`)
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
├── .env.example            # Template for local TCMS credentials (committed, .env is not)
├── Makefile                # Convenience targets: make test, make report, make kiwi-up
├── requirements.txt
└── README.md               # Quick start, adding tests guide, tool overview
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
2. Maps each Robot Framework test case to a Kiwi TCMS TestCase by name; if no matching TestCase exists it is auto-created under the configured Product/Plan
3. Records PASS/FAIL status on the TestRun in real time

Environment variables required:
```
TCMS_API_URL=http://localhost:8080/json-rpc/   # override with production URL in CI
TCMS_USERNAME=<secret>
TCMS_PASSWORD=<secret>
TCMS_PRODUCT=Bookstore
TCMS_PRODUCT_VERSION=v1
TCMS_BUILD=$GITHUB_SHA_SHORT
TCMS_PLAN_NAME=Regression
```

**Secret management:**
- In GitHub Actions: stored as repository secrets (`TCMS_USERNAME`, `TCMS_PASSWORD`, `TCMS_API_URL`) injected via `env:` in the workflow.
- Locally: copy `.env.example` to `.env` and fill in values; the `Makefile` loads it automatically. Never commit `.env`.
- If TCMS credentials are absent locally, omit `--listener kiwitcms_robotframework.Listener` — tests still run and produce Allure output.

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
  test-orders  — runs tests/orders/   (runs in parallel; each suite obtains its own token via auth.resource — no cross-job token passing required)

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
4. Uploads `allure-results/` as a GitHub Actions artifact (named exactly: `allure-results-auth`, `allure-results-books`, `allure-results-orders`)

**Allure merge strategy (`publish-report` job):**
- Downloads all three artifacts into separate subdirectories
- Copies all `*.json` files into a single `merged-allure-results/` directory. Filename collisions are avoided because each Robot run writes to a domain-specific subdirectory (`robot --outputdir results/allure-results-auth/`), so artifact contents never overlap.
- Runs `allure generate merged-allure-results/ -o allure-report/`
- Allure history is preserved by checking out the existing `gh-pages` branch and copying `allure-report/history/` into `merged-allure-results/history/` before generation

**Failure handling:** `publish-report` uses `if: always()` so the report is published even when one domain job fails, surfacing partial results.

### 6. Kiwi TCMS Infrastructure (`infra/`)

Docker Compose runs:
- `kiwitcms/kiwi` — the web application
- `postgres:15` — database
- `nginx` — TLS termination proxy

`deploy.sh` is a convenience wrapper that pulls images, runs migrations, and creates the superuser on first boot.

**Infrastructure notes (sample project scope):**
- Exposed on `localhost:8080` by default; nginx config included for production TLS (self-signed cert for dev, Let's Encrypt for production).
- PostgreSQL data is persisted to a named Docker volume (`kiwi_db_data`).
- No backup strategy is included in this sample — production deployments should add `pg_dump` to a cron job.
- The CI service account (`TCMS_USERNAME`) should be a dedicated low-privilege user created after first boot; superuser credentials are not used in CI.

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
- Kiwi TCMS listener failures are non-fatal — the RF run continues even if TCMS reporting is unavailable (controlled by `--listener` being optional in local runs). The listener has a 10-second connect timeout; after that it logs a warning and skips TCMS updates for the remainder of the run.
- If the Simple Books API is unreachable, `Suite Setup` marks the entire suite as `SKIP` (not `FAIL`), distinguishing infrastructure outages from real test failures. The GHA job exits with code 0 on SKIP so it does not block PRs during third-party downtime.
- Flaky test tolerance: no retry by default in this sample. A `robot --rerunfailed` pass can be added to the GHA job if needed.
- Pass rate threshold: 100% of non-skipped tests must pass for the CI job to succeed. SKIPped suites (due to unreachable API) exit 0 and do not block PRs. FAILed tests exit non-zero and block PRs.

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
4. Kiwi TCMS reflects the latest test run results (locally at `http://localhost:8080`; substitute production URL when deployed to `vitals.visithealth.ai`)
5. A new contributor can add a test case in under 5 minutes by following the README
