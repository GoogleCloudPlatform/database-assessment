SHELL := /bin/bash

# -----------------------------------------------------------------------------
# Display Formatting and Colors
# -----------------------------------------------------------------------------
BLUE := $(shell printf "\033[1;34m")
GREEN := $(shell printf "\033[1;32m")
RED := $(shell printf "\033[1;31m")
YELLOW := $(shell printf "\033[1;33m")
NC := $(shell printf "\033[0m")
INFO := $(shell printf "$(BLUE)ℹ$(NC)")
OK := $(shell printf "$(GREEN)✓$(NC)")
WARN := $(shell printf "$(YELLOW)⚠$(NC)")
ERROR := $(shell printf "$(RED)✖$(NC)")

# =============================================================================
# Configuration and Environment Variables
# =============================================================================
.DEFAULT_GOAL:=help
.ONESHELL:
.EXPORT_ALL_VARIABLES:
MAKEFLAGS += --no-print-directory

BUILD_DIR             =dist
SRC_DIR               =src
COLLECTOR_SRC_DIR     =scripts/collector
COLLECTOR_PACKAGE     =db-migration-assessment-collection-scripts
BASE_DIR              =$(shell pwd)

# If uv.toml exists, assume we need to force public PyPI for pip (used by pre-commit)
ifneq (,$(wildcard uv.toml))
export PIP_INDEX_URL=https://pypi.org/simple
endif

.EXPORT_ALL_VARIABLES:

ifndef VERBOSE
.SILENT:
endif


REPO_INFO ?= $(shell git config --get remote.origin.url)
COMMIT_SHA ?= git-$(shell git rev-parse --short HEAD)

# =============================================================================
# Help and Documentation
# =============================================================================

.PHONY: help
help:                                               ## Display this help text for Makefile
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

# =============================================================================
# Developer Utils
# =============================================================================
.PHONY: install-uv
install-uv:                                         ## Install latest version of uv
	@echo "${INFO} Installing uv..."
	@curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
	@echo "${OK} UV installed successfully"

.PHONY: install
install: destroy clean                              ## Install the project, dependencies, and pre-commit
	@echo "${INFO} Starting fresh installation..."
	@./tools/setup-local-env.sh
	@uv python pin 3.12 >/dev/null 2>&1
	@uv venv >/dev/null 2>&1
	@uv sync --all-extras --dev
	@echo "${OK} Installation complete! 🎉"

.PHONY: upgrade
upgrade:                                            ## Upgrade all dependencies to latest stable versions
	@echo "${INFO} Updating all dependencies... 🔄"
	@uv lock --upgrade
	@echo "${OK} Dependencies updated 🔄"
	@uv run pre-commit autoupdate
	@echo "${OK} Updated Pre-commit hooks 🔄"


.PHONY: clean
clean:                                              ## Cleanup temporary build artifacts
	@echo "${INFO} Cleaning working directory... 🧹"
	@rm -rf .pytest_cache .ruff_cache .hypothesis build/ dist/ .eggs/ .coverage coverage.xml coverage.json htmlcov/ .pytest_cache tests/.pytest_cache tests/**/.pytest_cache .mypy_cache .unasyncd_cache/ .auto_pytabs_cache node_modules >/dev/null 2>&1
	@find . -name '*.egg-info' -exec rm -rf {} + >/dev/null 2>&1
	@find . -type f -name '*.egg' -exec rm -f {} + >/dev/null 2>&1
	@find . -name '*.pyc' -exec rm -f {} + >/dev/null 2>&1
	@find . -name '*.pyo' -exec rm -f {} + >/dev/null 2>&1
	@find . -name '*~' -exec rm -f {} + >/dev/null 2>&1
	@find . -name '__pycache__' -exec rm -rf {} + >/dev/null 2>&1
	@find . -name '.ipynb_checkpoints' -exec rm -rf {} + >/dev/null 2>&1
	@echo "${OK} Working directory cleaned"

deep-clean: clean destroy                           ## Clean everything up
	@uv cache clean
	@echo "=> UV Cache cleaned successfully"

.PHONY: destroy
destroy:                                            ## Destroy the virtual environment
	@echo "${INFO} Destroying virtual environment... 🗑️"
	@uv run pre-commit clean >/dev/null 2>&1 || true
	@rm -rf .venv
	@echo "${OK} Virtual environment destroyed 🗑️"


.PHONY: build-collector
build-collector: 										## Build the collector SQL scripts.
	@tools/build-collector.sh

.PHONY: package-collector
package-collector:
	@tools/build-collector.sh

.PHONY: build
build: clean                                        ## Build and package the collectors and wheel
	@$(MAKE) build-collector
	@echo "=> Building package..."
	@uv build
	@echo "=> Package build complete..."

.PHONY: build-all
build-all: clean			## Build collector, wheel, and standalone collector binary
	@$(MAKE) build-collector
	@echo "=> Building sdist, wheel and binary packages..."
	@tools/build-binary-package.sh
	@echo "=> Package build complete..."


.PHONY: release
release:                                           ## Bump version and create release tag
	@echo "${INFO} Preparing for release... 📦"
	@make docs
	@make clean
	@uv lock --upgrade-package dma >/dev/null 2>&1
	@uv run bump-my-version bump $(bump)
	@uv run bump-my-version show current_version
	@echo "${OK} Release complete 🎉"

###############
# docs        #
###############
.PHONY: doc-privs
	## Extract the list of privileges required from code and create the documentation
doc-privs:
	@echo "# Create a user for Collection > docs/user_guide/shell_scripts/oracle/permissions.md" > docs/user_guide/shell_scripts/oracle/permissions.md
	@echo "" >> docs/user_guide/shell_scripts/oracle/permissions.md
	@echo " The collection scripts can be executed with any DBA account. Alternatively, create a new user with the minimum privileges required." >> docs/user_guide/shell_scripts/oracle/permissions.md
	@echo " The included script sql/setup/grants_wrapper.sql will grant the privileges listed below." >> docs/user_guide/shell_scripts/oracle/permissions.md
	@echo " Please see the Database User Scripts page for information on how to create the user." >> docs/user_guide/shell_scripts/oracle/permissions.md
	@echo "" >> docs/user_guide/shell_scripts/oracle/permissions.md
	@echo "## Permissions Required" >> docs/user_guide/shell_scripts/oracle/permissions.md
	@echo "" >> docs/user_guide/shell_scripts/oracle/permissions.md
	@echo "The following permissions are required for the script execution:" >> docs/user_guide/shell_scripts/oracle/permissions.md
	@echo "" >> docs/user_guide/shell_scripts/oracle/permissions.md
	@grep -e "Granting privs for Oracle Estate Explorer" -e "rectype_(" scripts/collector/oracle/sql/setup/grants_wrapper.sql | grep -v FUNCTION | sed "s/rectype_(//g;s/),//g;s/)//g;s/'//g;s/,/ ON /1;s/,/./g" >> docs/user_guide/shell_scripts/oracle/permissions.md
	@sed -i "" 's/    dbms_output.put_line(Granting privs for Oracle Estate Explorer;/\n\nThe following permissions are required for Oracle Estate Explorer if enabled:\n/g' docs/user_guide/shell_scripts/oracle/permissions.md

.PHONY: serve-docs
serve-docs:                                         ## Serve documentation locally
	@uv run mkdocs serve

.PHONY: docs
docs:                                               ## Generate HTML documentation
	@uv run mkdocs build


# =============================================================================
# Tests, Linting, Coverage
# =============================================================================
.PHONY: lint
lint:                                               ## Run pre-commit hooks; includes ruff linting, codespell
	@echo "=> Running pre-commit process"
	@uv run pre-commit run --all-files
	@echo "=> Pre-commit complete"

.PHONY: test
test:                                               ## Run the tests
	@echo "=> Running test cases"
	@uv run pytest -n 2 --dist loadgroup --cov
	@echo "=> Tests complete"

.PHONY: test-all-pythons
test-all-pythons:                                   ## Run the tests against all Python versions
	@echo "=> Running test cases for Python 3.9-3.13"
	@for version in 3.9 3.10 3.11 3.12 3.13; do \
		echo "=> Testing with Python $$version"; \
		uv run --python $$version pytest -n 2 --dist loadgroup --cov; \
	done
	@echo "=> Tests complete"
