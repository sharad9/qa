.PHONY: test report kiwi-up kiwi-down clean

# Load .env if present
ifneq (,$(wildcard .env))
  include .env
  export
endif

# Environment: local | uat | prod  (default: uat)
ENV ?= uat
VARS_FILE = resources/variables/$(ENV).yaml

# Run all tests with Allure listener (no TCMS listener required locally)
test:
	robot \
	  --listener allure_robotframework:results/allure-results \
	  --variablefile $(VARS_FILE) \
	  --outputdir results/robot-output \
	  tests/

# Run specific suite: make test-lab ENV=uat, make test-auth ENV=local, etc.
# Adds TCMS listener automatically if TCMS_API_URL is set in .env
test-%:
	robot \
	  --listener allure_robotframework:results/allure-results-$* \
	  --variablefile $(VARS_FILE) \
	  $(if $(TCMS_API_URL),--listener kiwitcms_robotframework.Listener,) \
	  --outputdir results/robot-output-$* \
	  tests/$*/

# Generate Allure HTML report from latest results
report:
	allure generate results/allure-results -o results/allure-report --clean
	@echo "Report ready — serve with:"
	@echo "  python3 -m http.server 8888 --directory results/allure-report"

# Start Kiwi TCMS via Docker Compose
kiwi-up:
	docker compose -f infra/docker-compose.yml up -d
	@echo "Kiwi TCMS starting at http://localhost:8080"

# Stop Kiwi TCMS
kiwi-down:
	docker compose -f infra/docker-compose.yml down

# Remove generated results
clean:
	rm -rf results/ merged-allure-results/
