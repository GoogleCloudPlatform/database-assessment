.DEFAULT_GOAL:=help
.ONESHELL:
USING_NPM             = $(shell python3 -c "if __import__('pathlib').Path('package-lock.json').exists(): print('yes')")
ENV_PREFIX		        =.venv/bin/
VENV_EXISTS           =	$(shell python3 -c "if __import__('pathlib').Path('.venv/bin/activate').exists(): print('yes')")
NODE_MODULES_EXISTS		=	$(shell python3 -c "if __import__('pathlib').Path('node_modules').exists(): print('yes')")
BUILD_DIR             =dist
SRC_DIR               =src
COLLECTOR_SRC_DIR     =scripts/collector
COLLECTOR_PACKAGE     =db-migration-assessment-collection-scripts
BASE_DIR              =$(shell pwd)

.EXPORT_ALL_VARIABLES:

ifndef VERBOSE
.SILENT:
endif


REPO_INFO ?= $(shell git config --get remote.origin.url)
COMMIT_SHA ?= git-$(shell git rev-parse --short HEAD)

help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)


# =============================================================================
# Developer Utils
# =============================================================================
install-pipx: 										## Install pipx
	@python3 -m pip install --upgrade --user pipx

install-hatch: 										## Install Hatch, UV, and Ruff
	@pipx install hatch --force
	@pipx inject hatch ruff uv hatch-pip-compile hatch-vcs --include-deps --include-apps --force

configure-hatch: 										## Configure Hatch defaults
	@hatch config set dirs.env.virtual .direnv
	@hatch config set dirs.env.pip-compile .direnv

upgrade-hatch: 										## Update Hatch, UV, and Ruff
	@pipx upgrade hatch --include-injected

install: 										## Install the project and all dependencies
	@if [ "$(VENV_EXISTS)" ]; then echo "=> Removing existing virtual environment"; $(MAKE) destroy-venv; fi
	@$(MAKE) clean
	@if [ "$(NODE_MODULES_EXISTS)" ]; then echo "=> Removing existing node modules"; $(MAKE) destroy-node_modules; fi
	@if ! pipx --version > /dev/null; then echo '=> Installing `pipx`'; $(MAKE) install-pipx ; fi
	@if ! hatch --version > /dev/null; then echo '=> Installing `hatch` with `pipx`'; $(MAKE) install-hatch ; fi
	@if ! hatch-pip-compile --version > /dev/null; then echo '=> Updating `hatch` and installing plugins'; $(MAKE) upgrade-hatch ; fi
	@echo "=> Creating Python environments..."
	@$(MAKE) configure-hatch
	@hatch env create local
	@if [ "$(USING_NPM)" ]; then echo "=> Installing NPM packages..."; hatch run local:python3 scripts/pre-build.py --install-packages && hatch run local:npm config set fund false; fi
	@echo "=> Install complete! Note: If you want to re-install re-run 'make install'"


.PHONY: upgrade
upgrade:       										## Upgrade all dependencies to the latest stable versions
	@echo "=> Updating all dependencies"
	@hatch-pip-compile --upgrade --all
	@echo "=> Python Dependencies Updated"
	@if [ "$(USING_NPM)" ]; then hatch run local:npm upgrade --latest; fi
	@echo "=> Node Dependencies Updated"
	@hatch run lint:pre-commit autoupdate
	@echo "=> Updated Pre-commit"


.PHONY: clean
clean: 														## remove all build, testing, and static documentation files
	@echo "=> Cleaning working directory"
	@rm -rf .pytest_cache .ruff_cache .hypothesis build/ dist/ .eggs/ .coverage coverage.xml coverage.json htmlcov/ .mypy_cache
	@find . -name '*.egg-info' -exec rm -rf {} +
	@find . -name '*.egg' -exec rm -f {} +
	@find . -name '*.pyc' -exec rm -f {} +
	@find . -name '*.pyo' -exec rm -f {} +
	@find . -name '*~' -exec rm -f {} +
	@find . -name '__pycache__' -exec rm -rf {} +
	@find . -name '.pytest_cache' -exec rm -rf {} +
	@find . -name '.ipynb_checkpoints' -exec rm -rf {} +
	@echo "=> Source cleaned successfully"

deep-clean: clean destroy-venv destroy-node_modules							## Clean everything up
	@hatch python remove all
	@echo "=> Hatch environments pruned and python installations trimmed"
	@uv cache clean
	@echo "=> UV Cache cleaned successfully"

destroy-venv: 											## Destroy the virtual environment
	@hatch env prune
	@hatch env remove lint
	@rm -Rf .venv
	@rm -Rf .direnv

destroy-node_modules: 											## Destroy the node environment
	@rm -rf node_modules .astro


.PHONY: build-collector
build-collector: 										## Build the collector SQL scripts.
	@rm -rf ./$(BUILD_DIR)/collector
	@echo "=> Building Assessment Data Collection Scripts for Oracle version $(VERSION)..."
	@mkdir -p $(BUILD_DIR)/collector/oracle/sql/extracts
	@mkdir -p $(BUILD_DIR)/collector/oracle/sql/extracts/awr
	@mkdir -p $(BUILD_DIR)/collector/oracle/sql/setup
	@mkdir -p $(BUILD_DIR)/collector/oracle/sql/extracts/statspack
	@cp scripts/collector/oracle/sql/*.sql $(BUILD_DIR)/collector/oracle/sql
	@cp scripts/collector/oracle/sql/extracts/*.sql $(BUILD_DIR)/collector/oracle/sql/extracts
	@cp scripts/collector/oracle/sql/extracts/awr/*.sql $(BUILD_DIR)/collector/oracle/sql/extracts/awr
	@cp scripts/collector/oracle/sql/setup/*.sql $(BUILD_DIR)/collector/oracle/sql/setup
	@cp scripts/collector/oracle/sql/extracts/statspack/*.sql $(BUILD_DIR)/collector/oracle/sql/extracts/statspack
	@cp scripts/collector/oracle/collect-data.sh $(BUILD_DIR)/collector/oracle/
	@cp scripts/collector/oracle/README.txt $(BUILD_DIR)/collector/oracle/
	@cp  LICENSE.txt $(BUILD_DIR)/collector/oracle
	echo "Database Migration Assessment Collector version $(VERSION) ($(COMMIT_SHA))" > $(BUILD_DIR)/collector/oracle/VERSION.txt

	@echo "=> Building Assessment Data Collection Scripts for Microsoft SQL Server version $(VERSION)..."
	@mkdir -p $(BUILD_DIR)/collector/sqlserver/sql/
	@cp scripts/collector/sqlserver/sql/*.sql $(BUILD_DIR)/collector/sqlserver/sql
	@cp scripts/collector/sqlserver/*.bat $(BUILD_DIR)/collector/sqlserver/
	@cp scripts/collector/sqlserver/*.ps1 $(BUILD_DIR)/collector/sqlserver/
	@cp scripts/collector/sqlserver/*.psm1 $(BUILD_DIR)/collector/sqlserver/
	@cp scripts/collector/sqlserver/README.txt $(BUILD_DIR)/collector/sqlserver/
	@cp  LICENSE.txt $(BUILD_DIR)/collector/sqlserver
	@echo "Database Migration Assessment Collector version $(VERSION) ($(COMMIT_SHA))" > $(BUILD_DIR)/collector/sqlserver/VERSION.txt

	@echo "=> Building Assessment Data Collection Scripts for MySQL version $(VERSION)..."
	@mkdir -p $(BUILD_DIR)/collector/mysql/sql/
	@mkdir -p $(BUILD_DIR)/collector/mysql/sql/5.7
	@mkdir -p $(BUILD_DIR)/collector/mysql/sql/base
	@cp scripts/collector/mysql/sql/*.sql $(BUILD_DIR)/collector/mysql/sql
	@cp scripts/collector/mysql/sql/5.7/*.sql $(BUILD_DIR)/collector/mysql/sql/5.7
	@cp scripts/collector/mysql/sql/base/*.sql $(BUILD_DIR)/collector/mysql/sql/base
	@cp scripts/collector/mysql/collect-data.sh $(BUILD_DIR)/collector/mysql/
	@cp -L scripts/collector/mysql/db-machine-specs.sh $(BUILD_DIR)/collector/mysql/
	@cp scripts/collector/mysql/README.txt $(BUILD_DIR)/collector/mysql/
	@cp  LICENSE.txt $(BUILD_DIR)/collector/mysql
	@echo "Database Migration Assessment Collector version $(VERSION) ($(COMMIT_SHA))" > $(BUILD_DIR)/collector/mysql/VERSION.txt

	@echo "=> Building Assessment Data Collection Scripts for Postgresql version $(VERSION)..."
	@mkdir -p $(BUILD_DIR)/collector/postgres/sql/
	@mkdir -p $(BUILD_DIR)/collector/postgres/sql/12
	@mkdir -p $(BUILD_DIR)/collector/postgres/sql/13
	@mkdir -p $(BUILD_DIR)/collector/postgres/sql/base
	@cp scripts/collector/postgres/sql/*.sql $(BUILD_DIR)/collector/postgres/sql
	@cp scripts/collector/postgres/sql/12/*.sql $(BUILD_DIR)/collector/postgres/sql/12
	@cp scripts/collector/postgres/sql/13/*.sql $(BUILD_DIR)/collector/postgres/sql/13
	@cp scripts/collector/postgres/sql/base/*.sql $(BUILD_DIR)/collector/postgres/sql/base
	@cp scripts/collector/postgres/collect-data.sh $(BUILD_DIR)/collector/postgres/
	@cp scripts/collector/postgres/db-machine-specs.sh $(BUILD_DIR)/collector/postgres/
	@cp scripts/collector/postgres/README.txt $(BUILD_DIR)/collector/postgres/
	@cp  LICENSE.txt $(BUILD_DIR)/collector/postgres
	@echo "Database Migration Assessment Collector version $(VERSION) ($(COMMIT_SHA))" > $(BUILD_DIR)/collector/postgres/VERSION.txt

	@make package-collector

.PHONY: package-collector
package-collector:
	@rm -f ./$(BUILD_DIR)/$(COLLECTOR_PACKAGE)*.bz2
	@rm -f ./$(BUILD_DIR)/$(COLLECTOR_PACKAGE)*.zip

	@echo  "=> Packaging Database Migration Assessment Collector for Oracle..."
	@echo "Zipping files in ./$(BUILD_DIR)/collector/oracle"
	@cd $(BASE_DIR)/$(BUILD_DIR)/collector/oracle; zip -r $(BASE_DIR)/$(BUILD_DIR)/$(COLLECTOR_PACKAGE)-oracle.zip  *

	@echo  "=> Packaging Database Migration Assessment Collector for Microsoft SQL Server..."
	@echo "Zipping files in ./$(BUILD_DIR)/collector/sqlserver"
	@cd $(BASE_DIR)/$(BUILD_DIR)/collector/sqlserver; zip -r $(BASE_DIR)/$(BUILD_DIR)/$(COLLECTOR_PACKAGE)-sqlserver.zip  *

	@echo  "=> Packaging Database Migration Assessment Collector for MySQL..."
	@echo "Zipping files in ./$(BUILD_DIR)/collector/mysql"
	@cd $(BASE_DIR)/$(BUILD_DIR)/collector/mysql; zip -r $(BASE_DIR)/$(BUILD_DIR)/$(COLLECTOR_PACKAGE)-mysql.zip  *

	@echo  "=> Packaging Database Migration Assessment Collector for Postgres..."
	@echo "Zipping files in ./$(BUILD_DIR)/collector/postgres"
	@cd $(BASE_DIR)/$(BUILD_DIR)/collector/postgres; zip -r $(BASE_DIR)/$(BUILD_DIR)/$(COLLECTOR_PACKAGE)-postgres.zip  *

.PHONY: build
build: clean        ## Build and package the collectors
	@$(MAKE) build-collector
	@echo "=> Building assets..."
	@if [ "$(USING_NPM)" ]; then echo "=> Building assets..."; hatch run local:python3 scripts/pre-build.py --build-assets; fi
	@echo "=> Building package..."
	@hatch build
	@echo "=> Package build complete..."

.PHONY: build-all
build-all: clean			## Build collector, wheel, and standalone collector binary
	@$(MAKE) build-collector
	@echo "=> Building sdist, wheel and binary packages..."
	@scripts/build-binary-package.sh
	@echo "=> Package build complete..."


.PHONY: pre-release
pre-release:       ## bump the version and create the release tag
	make docs
	make clean
	hatch run local:bump2version $(increment)
	head .bumpversion.cfg | grep ^current_version
	make build

###############
# docs        #
###############
.PHONY: doc-privs
doc-privs:   ## Extract the list of privileges required from code and create the documentation
	cat > docs/user_guide/oracle/permissions.md <<EOF
	# Create a user for Collection

	 The collection scripts can be executed with any DBA account. Alternatively, create a new user with the minimum privileges required.
	 The included script sql/setup/grants_wrapper.sql will grant the privileges listed below.
	 Please see the Database User Scripts page for information on how to create the user.

	## Permissions Required

	The following permissions are required for the script execution:

	 EOF
	 grep "rectype_(" scripts/collector/oracle/sql/setup/grants_wrapper.sql | grep -v FUNCTION | sed "s/rectype_(//g;s/),//g;s/)//g;s/'//g;s/,/ ON /1;s/,/./g" >> docs/user_guide/oracle/permissions.md

.PHONY: serve-docs
serve-docs:       ## Serve HTML documentation
	@hatch run docs:serve

.PHONY: docs
docs:       ## generate HTML documentation and serve it to the browser
	@hatch run docs:build


# =============================================================================
# Tests, Linting, Coverage
# =============================================================================
.PHONY: lint
lint: 												## Runs pre-commit hooks; includes ruff linting, codespell, black
	@echo "=> Running pre-commit process"
	@hatch run lint:fix
	@echo "=> Pre-commit complete"

.PHONY: test
test:  												## Run the tests
	@echo "=> Running test cases"
	@hatch run local:cov
	@echo "=> Tests complete"

.PHONY: test-all
test-all:  												## Run the tests against all python versions
	@echo "=> Running test cases"
	@hatch run test:cov
	@echo "=> Tests complete"
