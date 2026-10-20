# Workflows

## Continuous Integration (`ci.yaml`)

- Runs `make build-collector` to verify all database collection script archives package cleanly.
- Runs the test suite across Linux, macOS, and Windows for Python 3.10–3.13 via `test.yaml`.

## Release (`release.yaml`)

- Triggered when a GitHub Release is created (or manually via `workflow_dispatch`).
- Builds the Oracle, SQL Server, MySQL, and PostgreSQL collection script `.zip` packages and `dma-collection-masker`, then attaches them to the GitHub Release.

## Build and Publish Docs (`docs.yaml`)

- Builds the Sphinx documentation on pushes to `main` (when `docs/` changes) or via `workflow_dispatch`, and deploys the site to GitHub Pages.
