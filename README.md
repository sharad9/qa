# Visit Health QA Platform

Production-grade test pipeline for the Visit Health UAT APIs, covering Auth, Lab, and Pharmacy domains.

**Target APIs:**
- `https://api.samuraijack.xyz/latios` — Auth & Lab
- `https://api.getvisitapp.net/absol` — Pharmacy

## Stack

| Tool | Role |
|------|------|
| Robot Framework 6.1.1 | Test authoring & execution |
| Kiwi TCMS | Test management dashboard (`vitals.visithealth.ai`) |
| GitHub Actions | CI orchestration — 3 parallel domain jobs |
| Allure | Per-run HTML reports published to GitHub Pages |

## Quick Start

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Run all tests locally (Allure output only, no TCMS required)
make test

# 3. Generate and open the Allure HTML report
make report
python3 -m http.server 8888 --directory results/allure-report
# Then open http://localhost:8888

# 4. Run a single domain
make test-auth
make test-lab
make test-pharmacy
```

> **Note:** Allure reports require an HTTP server to load — opening `index.html` directly via `file://` will show blank due to browser CORS restrictions.

## Test Domains

| Suite | Tests | Covers |
|-------|-------|--------|
| `tests/auth/` | 3 | Doctor JWT login, user OTP flow, token verification |
| `tests/lab/` | 17 | Search labs, cart, addresses, partners, slots, patients, summary, dashboard, add/remove cart, select address/partner/slot/patient, transact, prescription upload, digitisation |
| `tests/pharmacy/` | 9 | Cart addresses, dashboard, patients, prescription upload, submit request, mark digitised, get carts, select cart |
| `tests/vitals/` | 3 | RF version check, Kiwi web reachability, Kiwi JSON-RPC |

**Total: 32 tests**

## With Kiwi TCMS

```bash
# Start Kiwi TCMS locally
make kiwi-up

# First time only — run migrations and create superuser
sudo bash infra/deploy.sh

# Copy credentials template
cp .env.example .env
# Edit .env: set TCMS_USERNAME and TCMS_PASSWORD

# Run tests with TCMS listener active
robot \
  --listener allure_robotframework \
  --listener kiwitcms_robotframework.Listener \
  --outputdir results/ \
  tests/
```

Open http://localhost:8080 to view live test runs in Kiwi TCMS.

## Adding a Test

1. Open `tests/<domain>/<domain>_tests.robot`
2. Copy an existing test case as a template
3. Tag it: `[Tags]    <domain>    regression`
4. Run locally: `robot tests/<domain>/`
5. All tests pass? Open a PR.

## Authentication

Tests use two auth flows — both handled automatically via `auth.resource`:

- **Doctor:** `POST /new-auth/doctor/login` with email/password → JWT
- **User:** `POST /new-auth/login-phone` + `POST /new-auth/otp` → JWT

The user token is fetched once per suite and cached — avoids the UAT OTP rate limit (15-minute lockout after multiple attempts).

Credentials are set in `resources/variables/default.yaml` (local) or as environment variables in CI.

## Project Structure

```
tests/
  auth/            — token lifecycle tests
  lab/             — lab booking flow tests
  pharmacy/        — pharmacy prescription tests
  vitals/          — platform self-tests
resources/
  common.resource          — Log Response, Verify Status Code
  auth.resource            — Get Doctor Token, Get User Token, User Auth Headers
  variables/default.yaml   — BASE_URL, credentials, test data IDs
infra/
  docker-compose.yml       — Kiwi TCMS + PostgreSQL + nginx
  deploy.sh                — first-boot migrations and superuser creation
.github/workflows/qa.yml   — CI pipeline
```

## CI / GitHub Actions

Every push to `main` and every PR triggers:

- Three parallel jobs: `test-auth`, `test-lab`, `test-pharmacy`
- A `publish-report` job that merges all Allure results and deploys to GitHub Pages

**Enable GitHub Pages (one-time):**
1. Go to repo **Settings → Pages**
2. Set Source to `gh-pages` branch, root `/`
3. Allure report will be at `https://<org>.github.io/<repo>/`

## Secrets Required (GitHub Actions)

| Secret | Value |
|--------|--------|
| `TCMS_API_URL` | `https://vitals.visithealth.ai/json-rpc/` |
| `TCMS_USERNAME` | CI service account username |
| `TCMS_PASSWORD` | CI service account password |

If secrets are absent the TCMS listener fails silently — tests still run and produce Allure output.
