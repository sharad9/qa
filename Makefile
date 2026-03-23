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
	rm -rf results/ merged-allure-results/
