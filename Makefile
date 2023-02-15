.DEFAULT_GOAL:=help
.ONESHELL:
VENV_EXISTS=$(shell python3 -c "if __import__('pathlib').Path('.venv/bin/activate').exists(): print('yes')")
VERSION := $(shell grep -m 1 current_version .bumpversion.cfg | tr -s ' ' | tr -d '"' | tr -d "'" | cut -d' ' -f3)
COLLECTOR_SRC_DIR=scripts/collector
BUILD_DIR=dist
COLLECTOR_PACKAGE=db-migration-assessment-collection-scripts
 

.EXPORT_ALL_VARIABLES:

ifndef VERBOSE
.SILENT:
endif


REPO_INFO ?= $(shell git config --get remote.origin.url)
COMMIT_SHA ?= git-$(shell git rev-parse --short HEAD)

help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)




.PHONY: install
install:	 ## Install the project in dev mode.
	@if [ "$(VENV_EXISTS)" ]; then source .venv/bin/activate; fi
	@if [ ! "$(VENV_EXISTS)" ]; then python3 -m venv .venv && source .venv/bin/activate; fi
	.venv/bin/pip install -U wheel setuptools cython pip && .venv/bin/pip install -U -r requirements.txt
	@echo "=> Build environment installed successfully.  ** If you want to re-install or update, 'make install'"


.PHONY: clean 
clean: clean-collector      ## remove all build, testing, and static documentation files
	rm -fr build/
	rm -fr dist/
	rm -fr .eggs/
	find . -name '*.egg-info' -exec rm -fr {} +
	find . -name '*.egg' -exec rm -f {} +
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	find . -name '__pycache__' -exec rm -fr {} +
	find . -name '.ipynb_checkpoints' -exec rm -fr {} +
	rm -fr .tox/
	rm -fr .coverage
	rm -fr coverage.xml
	rm -fr coverage.json
	rm -fr htmlcov/
	rm -fr .pytest_cache
	rm -fr .mypy_cache
	rm -fr site
	@echo "=> Source cleaned successfully"

.PHONY: clean-collector
clean-collector:
	@echo  "=> Cleaning previous build artifcats for data collector scripts..."
	rm -Rf $(BUILD_DIR)/collector/*


.PHONY: build-collector
build-collector: clean-collector      ## Build the collector SQL scripts.
	@echo "=> Building Assessment Data Collection Scripts for Oracle version $(VERSION)..."
	mkdir -p $(BUILD_DIR)/collector/oracle/sql/extracts
	mkdir -p $(BUILD_DIR)/collector/oracle/sql/extracts/awr
	mkdir -p $(BUILD_DIR)/collector/oracle/sql/setup
	mkdir -p $(BUILD_DIR)/collector/oracle/sql/extracts/statspack
	cp scripts/collector/oracle/sql/*.sql $(BUILD_DIR)/collector/oracle/sql
	cp scripts/collector/oracle/sql/extracts/*.sql $(BUILD_DIR)/collector/oracle/sql/extracts
	cp scripts/collector/oracle/sql/extracts/awr/*.sql $(BUILD_DIR)/collector/oracle/sql/extracts/awr
	cp scripts/collector/oracle/sql/setup/*.sql $(BUILD_DIR)/collector/oracle/sql/setup
	cp scripts/collector/oracle/sql/extracts/statspack/*.sql $(BUILD_DIR)/collector/oracle/sql/extracts/statspack
	cp scripts/collector/oracle/collect-data.sh $(BUILD_DIR)/collector/oracle/
	cp scripts/collector/oracle/README.txt $(BUILD_DIR)/collector/oracle/
	cp  LICENSE $(BUILD_DIR)/collector/oracle
	make package-collector
	echo "Database Migration Assessment Collector version $(VERSION) ($(COMMIT_SHA))" > $(BUILD_DIR)/collector/oracle/VERSION.txt

.PHONY: package-collector
package-collector:
	@echo  "=> Packaging Database Migration Assessment Collector for Oracle..."
	rm -f ./$(BUILD_DIR)/$(COLLECTOR_PACKAGE)*.bz2
	rm -f ./$(BUILD_DIR)/$(COLLECTOR_PACKAGE)*.zip
	@echo "Zipping files in ./$(BUILD_DIR)/collector/oracle"
	cd ./$(BUILD_DIR)/collector/oracle; zip -r ../../../$(BUILD_DIR)/$(COLLECTOR_PACKAGE)-oracle.zip  *


.PHONY: build
build: build-collector        ## Build and package the collectors


###############
# docs        #
###############
.PHONY: gen-docs
gen-docs:       ## generate HTML documentation
	./.venv/bin/mkdocs build

.PHONY: docs
docs:       ## generate HTML documentation and serve it to the browser
	./.venv/bin/mkdocs build
	./.venv/bin/mkdocs serve

.PHONY: pre-release
pre-release:       ## bump the version and create the release tag
	make gen-docs
	make clean
	./.venv/bin/bump2version $(increment)
	head .bumpversion.cfg | grep ^current_version
	make build
 
