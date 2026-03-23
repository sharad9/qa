# bookstore-qa

Sample QA platform demonstrating a production-grade test pipeline.

**Target:** [Simple Books API](https://simple-books-api.click)

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
|--------|--------|
| `TCMS_API_URL` | `https://vitals.visithealth.ai/json-rpc/` |
| `TCMS_USERNAME` | CI service account username |
| `TCMS_PASSWORD` | CI service account password |

If secrets are not set, the TCMS listener will fail silently and tests still produce Allure output.
