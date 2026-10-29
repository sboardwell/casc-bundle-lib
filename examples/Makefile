.DEFAULT_GOAL  := help
SHELL          := /bin/bash
MAKEFLAGS      += --no-print-directory

EXAMPLE_CHART  := casc-bundle
CHARTS_DIR     := $(EXAMPLE_CHART)/charts
LIBRARY_CHART  := ../charts/casc-bundle-lib
SERVICES       := oc mc

BOLD  := $(shell tput bold 2>/dev/null || true)
RESET := $(shell tput sgr0 2>/dev/null || true)

.PHONY: help
help: ## Show this help
	@echo "$(BOLD)casc-bundle example chart$(RESET)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_\/%-]+:.*## / \
	  { printf "  %-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

.PHONY: deps
deps: ## Resolve chart dependencies from the published OCI registry
	@mkdir -p $(CHARTS_DIR)
	helm dependency update $(EXAMPLE_CHART) --skip-refresh

.PHONY: $(addprefix lint/,$(SERVICES))
lint/%: deps ## Lint against services/%/values.yaml
	helm lint $(EXAMPLE_CHART) -f services/$*/values.yaml

.PHONY: $(addprefix render/,$(SERVICES))
render/%: deps ## Render with services/%/values.yaml
	helm template $* $(EXAMPLE_CHART) -f services/$*/values.yaml

.PHONY: $(addprefix extract/,$(SERVICES))
extract/%: deps ## Extract bundle files to rendered/%/
	@$(call extract-bundle,$*,services/$*/values.yaml)

define extract-bundle
	@rendered=$$(helm template $(1) $(EXAMPLE_CHART) -f $(2)); \
	name=$$(echo "$$rendered" | yq .metadata.name); \
	mkdir -p rendered/$$name; \
	for key in $$(echo "$$rendered" | yq '.data | keys | .[]'); do \
	  echo "$$rendered" | yq ".data[\"$$key\"]" > rendered/$$name/$$key; \
	  echo "  wrote rendered/$$name/$$key"; \
	done
endef

.PHONY: clean
clean: ## Remove the chart dependency directory, tarballs, and rendered output
	rm -rf $(CHARTS_DIR) rendered *.tgz
