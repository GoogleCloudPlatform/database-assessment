# Development Workflow: dma

**Last Updated**: Thursday, October 31, 2025

## Setup

### Prerequisites

- Python >= 3.10
- `uv` (can be installed with `make install-uv`)

### Installation

To set up the development environment, run:

```bash
make install
```

This will create a virtual environment, install all dependencies, and set up pre-commit hooks.

## Development Process

The project uses the Gemini Agent System for a structured development workflow.

### 1. Planning Phase

```bash
/prd "feature description"
```

This command creates a new workspace in `specs/active/feature-slug/` with a Product Requirements Document (PRD) and other planning artifacts.

### 2. Implementation Phase

```bash
/implement feature-slug
```

This command starts the implementation of the feature based on the PRD.

### 3. Testing Phase

```bash
/test feature-slug
```

This command is used to create and run tests for the implemented feature.

### 4. Review Phase

```bash
/review feature-slug
```

This command initiates the final review, documentation update, and archival of the feature workspace.

## Common Tasks

### Build

```bash
# Build the collector scripts and Python package
make build

# Build only the collector scripts
make build-collector
```

### Test

```bash
# Run the full test suite
make test
```

### Lint

```bash
# Run all linters and formatters
make lint
```

### Documentation

```bash
# Build the documentation site
make docs

# Serve the documentation site locally
make serve-docs
```

## Git Workflow

1. Create a new feature branch from `main`.
2. Make your changes and commit them. Ensure your commits pass the pre-commit hooks.
3. Push your branch and create a pull request.
4. Ensure all CI checks pass.
5. Request a review.
