.DEFAULT_GOAL:=help
.ONESHELL:
ENV_PREFIX=$(shell python3 -c "if __import__('pathlib').Path('.venv/bin/pip').exists(): print('.venv/bin/')")
VENV_EXISTS=$(shell python3 -c "if __import__('pathlib').Path('.venv/bin/activate').exists(): print('yes')")
GRPC_PYTHON_BUILD_SYSTEM_ZLIB=true

.EXPORT_ALL_VARIABLES:

ifndef VERBOSE
.SILENT:
endif


REPO_INFO ?= $(shell git config --get remote.origin.url)
COMMIT_SHA ?= git-$(shell git rev-parse --short HEAD)

help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)


.PHONY: upgrade-dependencies
upgrade-dependencies:          ## Upgrade all dependencies to the latest stable versions
	${ENV_PREFIX}pip-compile -r requirements/base.in > requirements/base.txt
	${ENV_PREFIX}pip-compile -r requirements/dev.in > requirements/dev.txt
	${ENV_PREFIX}pip-compile -r requirements/lint.in > requirements/lint.txt

.PHONY: install
install:          ## Install the project in dev mode.
	@if [ "$(VENV_EXISTS)" ]; then echo "Removing existing environment"; fi
	@if [ "$(VENV_EXISTS)" ]; then rm -Rf .venv; fi
	python3 -m venv .venv && source .venv/bin/activate && .venv/bin/pip install -U wheel setuptools cython pip
	${ENV_PREFIX}pip install -r requirements.txt
	${ENV_PREFIX}pip install .


.PHONY: install-dev
install-dev:
	@if [ "$(VENV_EXISTS)" ]; then echo "Removing existing environment"; fi
	@if [ "$(VENV_EXISTS)" ]; then rm -Rf .venv; fi
	python3 -m venv .venv && source .venv/bin/activate && .venv/bin/pip install -U wheel setuptools cython pip
	${ENV_PREFIX}pip install -r requirements/dev.txt
	${ENV_PREFIX}pip install -r requirements/lint.txt
	${ENV_PREFIX}pip install -e .

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


.PHONY: gen-docs
gen-docs:       ## generate HTML documentation
	${ENV_PREFIX}mkdocs build

.PHONY: docs
docs:       ## generate HTML documentation and serve it to the browser
	${ENV_PREFIX}mkdocs build
	${ENV_PREFIX}mkdocs serve