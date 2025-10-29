# Testing Guide: dma

**Last Updated**: 2025-10-29

## Test Framework

dma uses **pytest** for testing.

## Running Tests

```bash
make test
```

## Test Structure

```
tests/
├── integration/
└── unit/
```

## Test Standards

- **Framework**: pytest
- **Coverage Target**: >85%
- **Test Style**: Function-based, not class-based
- **Fixtures**: Use pytest fixtures for setup/teardown
- **Markers**: Use pytest markers for categorization
- **Parallel Execution**: Tests must be parallelizable

## Writing Tests

All new logic must be accompanied by tests. The test suite must pass (`make test`).

## Coverage Requirements

The project aims for a test coverage of over 85%.

## Continuous Integration

The project uses GitHub Actions for CI. The CI pipeline runs tests on all pull requests.
