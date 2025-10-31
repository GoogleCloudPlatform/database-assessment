# Code Style Guide: dma

**Last Updated**: Thursday, October 31, 2025

## Language & Version

- **Language**: Python
- **Version**: >=3.10

## Formatting

Formatting is handled automatically by `ruff format`, which is configured to be compatible with `black`. All code must be formatted before committing. This is enforced by pre-commit hooks.

## Linting

The project uses `ruff`, `mypy`, and `pylint` for static analysis. All code must pass the linting checks before being merged.

To run the linters:

```bash
make lint
```

This command is also run as part of the pre-commit hooks.

## Type Hints

The project is partially typed. New code should include type hints where possible. The project uses `mypy` to check type correctness.

## Import Organization

Imports are automatically organized by `ruff`'s isort integration. The configuration in `pyproject.toml` specifies the first-party modules.

## Naming Conventions

-   **Modules**: `snake_case`
-   **Classes**: `PascalCase`
-   **Functions**: `snake_case`
-   **Variables**: `snake_case`
-   **Constants**: `UPPER_SNAKE_CASE`

## Documentation

Docstrings should follow the **Google** convention, as configured in `pyproject.toml` for `pydocstyle`. All public modules, classes, and functions should have docstrings.
