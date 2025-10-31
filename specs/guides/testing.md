# Testing Guide: dma

**Last Updated**: Thursday, October 31, 2025

## Test Framework

The `dma` project uses **pytest** for testing.

## Running Tests

The entire test suite can be run using Make:

```bash
# Run all tests with coverage
make test

# Run tests against all supported Python versions
make test-all-pythons
```

Individual tests can be run using the `pytest` command directly:

```bash
uv run pytest tests/unit/test_cli.py
```

## Test Structure

Tests are organized into two main directories:

-   `tests/unit/`: For unit tests that test individual components in isolation. These tests should not have external dependencies like databases.
-   `tests/integration/`: For integration tests that verify the interaction between different components, including tests that require a live database connection.

## Test Standards

-   **Fixtures**: Use pytest fixtures for setting up and tearing down test resources, such as database connections or temporary files. See `tests/conftest.py` for examples.
-   **Markers**: Tests are categorized using pytest markers (e.g., `@pytest.mark.mysql`). This allows running tests for a specific database dialect.
-   **Mocking**: Use `pytest-mock` for mocking objects and functions.
-   **Assertions**: Use standard `assert` statements.

## Writing Tests

-   New code should be accompanied by corresponding unit and/or integration tests.
-   Tests should be placed in the appropriate directory (`unit` or `integration`).
-   Follow the existing naming conventions for test files and functions (e.g., `test_*.py`).

## Coverage Requirements

The project aims for a high level of test coverage. Pull requests should not decrease the overall coverage percentage. You can view the coverage report by running `make test` and then opening the `htmlcov/index.html` file.
