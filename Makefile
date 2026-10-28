.DEFAULT_GOAL  := help
SHELL          := /bin/bash
MAKEFLAGS      += --no-print-directory

LIBRARY_CHART  := charts/casc-bundle-lib
EXAMPLE_CHART    := examples/chart/casc-bundle
EXAMPLE_CHARTS_DIR := $(EXAMPLE_CHART)/charts
VALUES_OC        := examples/chart/values-oc.yaml
VALUES_MC        := examples/chart/values-mc.yaml

BOLD  := $(shell tput bold 2>/dev/null || true)
RESET := $(shell tput sgr0 2>/dev/null || true)

.PHONY: help
help: ## Show this help
	@echo "$(BOLD)casc-bundle-lib — Helm library chart for CloudBees CI CasC bundles$(RESET)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_\/%-]+:.*## / \
	  { printf "  %-24s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

.PHONY: lint
lint: ## Lint the library chart
	helm lint $(LIBRARY_CHART)

.PHONY: examples/deps
examples/deps: ## Package the library into the example chart's charts/ directory (replaces helm dependency update locally)
	@mkdir -p $(EXAMPLE_CHARTS_DIR)
	helm package $(LIBRARY_CHART) -d $(EXAMPLE_CHARTS_DIR)

.PHONY: examples/lint
examples/lint: examples/deps ## Lint the example chart against both values files
	helm lint $(EXAMPLE_CHART) -f $(VALUES_OC)
	helm lint $(EXAMPLE_CHART) -f $(VALUES_MC)

.PHONY: examples/test
examples/test: examples/deps ## Run the helm-unittest suite against the example chart
	helm unittest $(EXAMPLE_CHART)

.PHONY: examples/render/oc
examples/render/oc: examples/deps ## Render the example chart with the OC values
	helm template oc $(EXAMPLE_CHART) -f $(VALUES_OC)

.PHONY: examples/render/mc
examples/render/mc: examples/deps ## Render the example chart with the MC values
	helm template mc $(EXAMPLE_CHART) -f $(VALUES_MC)

.PHONY: examples/extract/oc
examples/extract/oc: examples/deps ## Extract OC bundle files to rendered/<name>/
	@$(call extract-bundle,oc,$(VALUES_OC))

.PHONY: examples/extract/mc
examples/extract/mc: examples/deps ## Extract MC bundle files to rendered/<name>/
	@$(call extract-bundle,mc,$(VALUES_MC))

define extract-bundle
	@rendered=$$(helm template $(1) $(EXAMPLE_CHART) -f $(2)); \
	name=$$(echo "$$rendered" | yq .metadata.name); \
	mkdir -p rendered/$$name; \
	for key in $$(echo "$$rendered" | yq '.data | keys | .[]'); do \
	  echo "$$rendered" | yq ".data[\"$$key\"]" > rendered/$$name/$$key; \
	  echo "  wrote rendered/$$name/$$key"; \
	done
endef

.PHONY: examples/clean
examples/clean: ## Remove the example chart's dependency directory, tarballs, and rendered output
	rm -rf $(EXAMPLE_CHARTS_DIR) rendered *.tgz
