# Development Workflow: dma

**Last Updated**: 2025-10-29

## Setup

### Prerequisites

- Python >= 3.10
- uv

### Installation

```bash
make install
```

## Development Process

### 1. Planning Phase

```bash
/prd "feature description"
```

Creates workspace in `specs/active/feature-slug/`.

### 2. Implementation Phase

```bash
/implement feature-slug
```

Implements feature and auto-invokes testing and documentation.

### 3. Review Phase

```bash
/review feature-slug
```

Quality gate, knowledge capture, and archival.

## Common Tasks

### Build

```bash
make build
```

### Test

```bash
make test
```

### Lint

```bash
make lint
```

### Documentation

```bash
make docs
```

## Git Workflow

- **Branching**: Feature branches from `main`
- **Commits**: Conventional commits (feat:, fix:, docs:, etc.)
- **PRs**: Require passing CI before merge
- **Hooks**: Pre-commit hooks for linting/formatting
