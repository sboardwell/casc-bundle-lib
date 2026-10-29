.DEFAULT_GOAL  := help
SHELL          := /bin/bash
MAKEFLAGS      += --no-print-directory

LIBRARY_CHART  := charts/casc-bundle-lib
TEST_CONSUMER  := charts/casc-bundle-lib-test-consumer

BOLD  := $(shell tput bold 2>/dev/null || true)
RESET := $(shell tput sgr0 2>/dev/null || true)

.PHONY: help
help: ## Show this help
	@echo "$(BOLD)casc-bundle-lib — Helm library chart for CloudBees CI CasC bundles$(RESET)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_\/%-]+:.*## / \
	  { printf "  %-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

.PHONY: lint
lint: ## Lint the library chart
	helm lint $(LIBRARY_CHART)

.PHONY: test/deps
test/deps: ## Sync local library into the test-consumer charts/ directory (Helm v4 requires unpacked)
	@mkdir -p $(TEST_CONSUMER)/charts
	@rm -rf $(TEST_CONSUMER)/charts/$(notdir $(LIBRARY_CHART))
	@cp -r $(LIBRARY_CHART) $(TEST_CONSUMER)/charts/$(notdir $(LIBRARY_CHART))

.PHONY: test
test: test/deps ## Run the helm-unittest suite against the test consumer
	helm unittest $(TEST_CONSUMER)

.PHONY: ci
ci: ## Run the CI test job locally via act (skips verify-lockfile — GitHub-only)
	act -j test

.PHONY: package
package: ## Package the library chart
	helm package $(LIBRARY_CHART)
