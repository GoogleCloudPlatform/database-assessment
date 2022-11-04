.DEFAULT_GOAL:=help
.ONESHELL:
ENV_PREFIX=$(shell python3 -c "if __import__('pathlib').Path('.venv/bin/pip').exists(): print('.venv/bin/')")
USING_POETRY=$(shell grep "tool.poetry" pyproject.toml && echo "yes")
USING_PNPM=$(shell python3 -c "if __import__('pathlib').Path('pnpm-lock.yaml').exists(): print('yes')")
USING_YARN=$(shell python3 -c "if __import__('pathlib').Path('yarn.lock').exists(): print('yes')")
USING_NPM=$(shell python3 -c "if __import__('pathlib').Path('package-lock.json').exists(): print('yes')")
VENV_EXISTS=$(shell python3 -c "if __import__('pathlib').Path('.venv/bin/activate').exists(): print('yes')")
NODE_MODULES_EXISTS=$(shell python3 -c "if __import__('pathlib').Path('node_modules').exists(): print('yes')")
# PYTHON_PACKAGES=$(shell poetry export -f requirements.txt  --without-hashes |cut -d'=' -f1 |cut -d ' ' -f1)
# grep the version from pyproject.toml, squeeze multiple spaces, delete double
#   and single quotes, get 3rd val. This command tolerates 
#   multiple whitespace sequences around the version number
VERSION := $(shell grep -m 1 version pyproject.toml | tr -s ' ' | tr -d '"' | tr -d "'" | cut -d' ' -f3)
GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
COLLECTOR_SRC_DIR=src/collector
BUILD_DIR=dist
COLLECTOR_PACKAGE=collection_scripts.tar
BUILD_DIR=dist

.EXPORT_ALL_VARIABLES:

ifndef VERBOSE
.SILENT:
endif


REPO_INFO ?= $(shell git config --get remote.origin.url)
COMMIT_SHA ?= git-$(shell git rev-parse --short HEAD)

help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)


.PHONY: upgrade-dependencies
upgrade-dependencies:       ## Upgrade all dependencies to the latest stable versions
	if [ "$(USING_POETRY)" ]; then poetry update; fi
	@echo "=> Python Dependencies Updated"
	if [ "$(USING_NPM)" ]; then npm upgrade --latest; fi
	if [ "$(USING_YARN)" ]; then yarn upgrade; fi
	if [ "$(USING_PNPM)" ]; then pnpm upgrade --latest; fi
	@echo "=> Node Dependencies Updated"
 
###############
# app         #
###############
.PHONY: install-runtime-only
install-runtime-only:          ## Install the project with run only dependencies
	@if ! poetry --version > /dev/null; then echo 'poetry is required, installing from from https://python-poetry.org/'; curl -sSL https://install.python-poetry.org | python3 -; fi
	@if [ "$(VENV_EXISTS)" ]; then echo "Removing existing environment"; fi
	if [ "$(VENV_EXISTS)" ]; then rm -Rf .venv; fi
	if [ "$(USING_POETRY)" ]; then poetry config virtualenvs.in-project true  && poetry config virtualenvs.options.always-copy true && python3 -m venv .venv && source .venv/bin/activate && .venv/bin/pip install -U wheel setuptools cython pip && poetry install --with main && exit; fi
	if [ "$(USING_NPM)" ]; then npm install; fi
	@echo "=> Install complete.  ** If you want to re-install re-run 'install-runtime-only'"



.PHONY: install
install:	 ## Install the project in dev mode.
	@if ! poetry --version > /dev/null; then echo 'poetry is required, installing from from https://install.python-poetry.org'; curl -sSL https://install.python-poetry.org | python3 -; fi
	@if [ "$(VENV_EXISTS)" ]; then echo "Removing existing environment"; fi
	if [ "$(VENV_EXISTS)" ]; then rm -Rf .venv; fi
	if [ "$(USING_POETRY)" ]; then poetry config virtualenvs.in-project true  && poetry config virtualenvs.options.always-copy true && python3 -m venv .venv && source .venv/bin/activate && .venv/bin/pip install -U wheel setuptools cython pip && poetry install --with linting,dev,docs && exit; fi
	if [ "$(USING_NPM)" ]; then npm install; fi
	@echo "=> Install complete.  ** If you want to re-install re-run 'make install'"


.PHONY: clean
clean:       ## remove all build, testing, and static documentation files
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

###############
# builds      #
###############
build-server: $(BUILD_DIR)

$(BUILD_DIR): $(shell find $(SERVER_SRC_DIR))
	@poetry build

clean-collector:
	@echo  "=> Cleaning previous build artifcats for data collector scripts..."
	rm -Rf $(BUILD_DIR)/collector/*



build-collector: clean-collector          ## Build the collector SQL scripts.
	@echo "=> Building Advisor Data Collection Scripts..."
	
	mkdir -p $(BUILD_DIR)/collector/sql/extracts
	cp src/collector/sql/*.sql $(BUILD_DIR)/collector/sql
	cp src/collector/sql/*.sed $(BUILD_DIR)/collector/sql
	cp src/collector/sql/extracts/*.sql $(BUILD_DIR)/collector/sql/extracts
	cp src/collector/collect-data.sh $(BUILD_DIR)/collector
	cp src/collector/README.txt $(BUILD_DIR)/collector
	cp  LICENSE $(BUILD_DIR)/collector
	echo "Advisor Data Extractor version $(VERSION) ($(COMMIT_SHA))" > $(BUILD_DIR)/collector/VERSION.txt


.PHONY: build
build: build-collector build-server          ## Install the project in dev mode.

package-collector:
	@echo  "=> Packaging Data Extractor..."
	rm -f ./$(BUILD_DIR)/$(COLLECTOR_PACKAGE).bz2
	tar -C ./$(BUILD_DIR) -cjf  $(BUILD_DIR)/$(COLLECTOR_PACKAGE).bz2  collector/




.PHONY: migrations
###############
# docs        #
###############
.PHONY: gen-docs
gen-docs:       ## generate HTML documentation
	poetry run mkdocs build

.PHONY: docs
docs:       ## generate HTML documentation and serve it to the browser
	poetry run mkdocs build
	poetry run mkdocs serve

.PHONY: pre-release
pre-release:       ## bump the version and create the release tag
	make check
	make gen-docs
	make clean
	poetry run bump2version $(increment)
	git describe --tags --abbrev=0
	head pyproject.toml | grep version
	cat src/dbma/version.py
	make build-collector
	make package-collector


###########
# license #
###########

# .PHONY: licenses
# licenses: 			## Generate licenses
# 	@echo "Generating Licenses"
# 	@poetry run pip-licenses --with-urls --format=markdown --order=name --packages ${PYTHON_PACKAGES}

# .PHONY: license-file
# license-file: 		## Generate licenses
# 	@echo "Generating License file"
# 	@poetry run pip-licenses --packages ${PYTHON_PACKAGES} --format=plain-vertical --with-license-file --no-license-path > NOTICE
