# Development Commands

All commands should be run from the project root directory.

## Environment Management

### `make install-uv`

Installs the latest version of UV package manager.

**Usage:**

```bash
make install-uv
```

### `make install`

Creates a fresh virtual environment and installs all dependencies (development, testing, linting, and documentation).

**Usage:**

```bash
make install
```

**What it does:**

- Destroys any existing virtual environment
- Pins Python to version 3.12
- Creates `.venv/` virtual environment
- Installs all dependencies with `uv sync --all-extras --dev`
- Installs pre-commit hooks

### `make upgrade`

Upgrades all dependencies to their latest stable versions and updates pre-commit hooks.

**Usage:**

```bash
make upgrade
```

**What it does:**

- Updates `uv.lock` with latest dependency versions
- Updates pre-commit hook versions

### `make destroy`

Removes the virtual environment completely.

**Usage:**

```bash
make destroy
```

## Building

### `make build-collector`

Builds database collection script packages (ZIP files) for all supported databases.

**Usage:**

```bash
make build-collector
```

**Output:** Creates ZIP files in `dist/`:

- `db-migration-assessment-collection-scripts-oracle.zip`
- `db-migration-assessment-collection-scripts-sqlserver.zip`
- `db-migration-assessment-collection-scripts-mysql.zip`
- `db-migration-assessment-collection-scripts-postgres.zip`

### `make build`

Builds both collection script packages and the Python wheel.

**Usage:**

```bash
make build
```

**What it does:**

- Runs `make build-collector`
- Runs `uv build` to create wheel and sdist

**Output:** Creates in `dist/`:

- Collection script ZIP files
- `dma-{version}-py3-none-any.whl`
- `dma-{version}.tar.gz`

### `make clean`

Removes all build artifacts, test files, and temporary files.

**Usage:**

```bash
make clean
```

**What it removes:**

- `dist/`, `build/`, `.eggs/`
- `*.egg-info`, `*.pyc`, `__pycache__/`
- `.pytest_cache`, `.ruff_cache`, `.mypy_cache`
- `.coverage`, `coverage.xml`, `htmlcov/`

### `make deep-clean`

Performs a deep clean including virtual environment and UV cache.

**Usage:**

```bash
make deep-clean
```

## Testing

### `make test`

Runs the full test suite with coverage reporting (Python 3.12).

**Usage:**

```bash
make test
```

**Equivalent to:**

```bash
uv run pytest -n 2 --cov
```

### `make test-all-pythons`

Runs tests against all supported Python versions (3.9, 3.10, 3.11, 3.12, 3.13).

**Usage:**

```bash
make test-all-pythons
```

**Note:** This requires multiple Python versions to be installed on your system.

### Run Specific Tests

```bash
# Run specific test file
uv run pytest tests/unit/test_example.py

# Run with debugging
uv run pytest -s --pdb tests/unit/test_example.py

# Run tests matching a pattern
uv run pytest -k "test_database"

# Run tests without coverage
uv run pytest --no-cov
```

### Collection Script Tests

These tests execute the packaged collection scripts inside containers, then validate the output archives.
They require Docker or Podman.

```bash
# Run all collection script tests
uv run pytest -m script_test

# Run Postgres script tests only
uv run pytest -m "script_test and postgres"

# Skip slow tests
uv run pytest -m "script_test and not slow"
```

**Environment variables:**

- `DMA_TEST_KEEP_VOLUMES=1` keeps container volumes for debugging.

**Structure:** Script tests live under `tests/integration/<db>/test_collection_scripts.py` and
share session-scoped fixtures from `tests/lib/collector_build.py` and
`tests/lib/script_executor.py` to avoid rebuilding artifacts per test.

## Linting and Code Quality

### `make lint`

Runs all pre-commit hooks including ruff linting, formatting, and codespell.

**Usage:**

```bash
make lint
```

**What it runs:**

- Python AST validation
- TOML/YAML/JSON validation
- Ruff linting and formatting
- Codespell spell checking
- Trailing whitespace fixes
- End-of-file fixes

### Manual Linting Commands

```bash
# Run only ruff linting
uv run ruff check .

# Auto-fix ruff issues
uv run ruff check --fix .

# Format code
uv run ruff format .

# Run mypy type checking
uv run mypy src/dma

# Run codespell
uv run codespell
```

## Documentation

### `make docs`

Generates HTML documentation from Markdown files.

**Usage:**

```bash
make docs
```

**Output:** Creates documentation in `site/`

### `make serve-docs`

Builds and serves documentation locally with auto-reload.

**Usage:**

```bash
make serve-docs
```

**Access:** Opens at `http://localhost:8000`

### `make doc-privs`

Extracts Oracle privilege requirements from code and updates documentation.

**Usage:**

```bash
make doc-privs
```

**Output:** Updates `docs/user_guide/shell_scripts/oracle/permissions.md`

## Version Management

### `make release`

Bumps the version number, updates all version references, and builds release artifacts.

**Usage:**

```bash
# Bump patch version (e.g., 4.3.44 → 4.3.45)
make release bump=patch

# Bump minor version (e.g., 4.3.44 → 4.4.0)
make release bump=minor

# Bump major version (e.g., 4.3.44 → 5.0.0)
make release bump=major
```

**What it does:**

1. Generates documentation
2. Cleans build artifacts
3. Bumps version in all files using `bump-my-version`
4. Builds collection scripts and wheel

**Files updated:**

- `pyproject.toml`
- `uv.lock`
- `scripts/masker/dma-collection-masker`
- `scripts/collector/oracle/collect-data.sh`
- `scripts/collector/mysql/collect-data.sh`
- `scripts/collector/postgres/collect-data.sh`
- `scripts/collector/sqlserver/instanceReview.ps1`

### Manual Version Commands

```bash
# Show current version
uv run bump-my-version show current_version

# Dry run version bump
uv run bump-my-version bump --dry-run patch
```

## Running the CLI Locally

### Using UV (Recommended)

```bash
# Run readiness check
uv run dma readiness-check --db-type postgres --hostname localhost

# Run data collection
uv run dma collect-data --db-type mysql --hostname localhost
```

### Using Activated Virtual Environment

```bash
source .venv/bin/activate

dma readiness-check --db-type postgres --hostname localhost
dma collect-data --db-type mysql --hostname localhost
```

## Database-Specific Testing

### Start Test Databases

Test containers are managed automatically by pytest fixtures. Running tests will
start and stop the required containers as needed.

To keep volumes between runs, set `DMA_TEST_KEEP_VOLUMES=1` in the environment.

### Run Database-Specific Tests

```bash
# MySQL tests only
uv run pytest -m mysql

# PostgreSQL tests only
uv run pytest -m postgres

# Oracle tests only
uv run pytest -m oracle

# SQL Server tests only
uv run pytest -m mssql
```

## Dependency Groups

The project uses UV dependency groups defined in `pyproject.toml`:

- **dev**: Test dependencies (pytest, pytest-cov, etc.)
- **lint**: Linting tools (ruff, mypy, pre-commit, etc.)
- **docs**: Documentation tools (mkdocs, mkdocs-material, etc.)
- **build**: Build tools (bump-my-version)

### Install Specific Groups

```bash
# Install only docs dependencies
uv sync --group docs

# Install only lint dependencies
uv sync --group lint

# Install multiple groups
uv sync --group docs --group lint
```

## Useful UV Commands

```bash
# Show installed packages
uv pip list

# Show dependency tree
uv pip tree

# Add a new dependency
uv add requests

# Add a dev dependency
uv add --dev pytest-timeout

# Remove a dependency
uv remove requests

# Sync environment with lockfile
uv sync --locked
```

## Quick Reference

| Task | Command |
|------|---------|
| Set up environment | `make install` |
| Run tests | `make test` |
| Run linting | `make lint` |
| Build everything | `make build` |
| Clean artifacts | `make clean` |
| Serve docs | `make serve-docs` |
| Bump version | `make release bump=patch` |
| Run CLI | `uv run dma --help` |
