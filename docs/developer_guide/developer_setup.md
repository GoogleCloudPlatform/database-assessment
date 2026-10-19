# Developer Setup

To begin local development, clone the [GoogleCloudPlatform/database-assessment](https://github.com/GoogleCloudPlatform/database-assessment) repository and follow the setup instructions below. All commands should be executed from the project root directory.

## Prerequisites

- **Python 3.10+** (UV will manage Python versions for you)
- **Git** for version control
- **UV** package manager (installed automatically via `make install-uv`)
- **Docker** or **Podman** (required only for running container-backed integration tests)

## Quick Start

### 1. Install UV (if not already installed)

```bash
make install-uv
```

This installs the latest version of [UV](https://github.com/astral-sh/uv), a fast Python package and environment manager.

### 2. Set up Development Environment

```bash
make install
```

This command will:
- Pin Python to version 3.12
- Create a virtual environment at `.venv/`
- Install all development dependencies (`lint`, `test`, `docs`, and `build` groups) via `uv sync --dev`
- Install pre-commit hooks for code quality checks

### 3. Activate the Virtual Environment (Optional)

The `make` commands use `uv run` automatically, but if you want to work directly in the shell:

```bash
source .venv/bin/activate
```

## Development Workflow

### Update Dependencies

To upgrade all dependencies to their latest versions:

```bash
make upgrade
```

This updates `uv.lock` and refreshes pre-commit hooks.

## Verify Installation

Test that everything is set up correctly:

```bash
# Run unit tests
make test-unit

# Run linting
make lint

# Build collector script packages
make build
```

## IDE Setup

### VS Code

The project includes `.vscode/settings.json` with recommended Python settings. UV's virtual environment at `.venv/` should be auto-detected.

### PyCharm

1. Go to **Settings → Project → Python Interpreter**
2. Add a new interpreter pointing to `.venv/bin/python`
3. Enable pytest as the default test runner

## Troubleshooting

### UV Not Found

If `uv` command is not found after `make install-uv`, add it to your PATH:

```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/.cargo/bin:$PATH"
```

Then reload your shell:

```bash
source ~/.bashrc  # or ~/.zshrc
```

### Pre-commit Hook Failures

If pre-commit hooks fail, fix the issues and re-run:

```bash
uv run pre-commit run --all-files
```

### Dependency Conflicts

If you encounter dependency resolution issues:

```bash
# Clean and reinstall
make destroy
make install
```

## Next Steps

- Read [Commands](commands.md) for available development commands
- Read [Workflows](workflows.md) for CI/CD information
- Read [Releases](releases.md) for release process
- See [Contributing](../contributing.md) for contribution guidelines
