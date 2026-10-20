# Releases

This document describes the release process for the Database Migration Assessment collection scripts.

## Prerequisites

- Clean, up-to-date copy of the `main` branch
- All tests passing (`make test`)
- All linting checks passing (`make lint`)
- Documentation built successfully (`make docs-build`)
- Collaborator access to the repository

## Release Process

A release consists of two steps executed from a tested and linted `main` branch:

### Step 1: Bump Version

```bash
make release bump={major/minor/patch}
```

**What this does:**

1. Generates documentation (`make docs-build`)
2. Cleans build artifacts (`make clean`)
3. Uses `bump-my-version` to increment the version number in:
   - `pyproject.toml`
   - `scripts/masker/dma-collection-masker`
   - `scripts/collector/oracle/collect-data.sh`
   - `scripts/collector/mysql/collect-data.sh`
   - `scripts/collector/postgres/collect-data.sh`
   - `scripts/collector/sqlserver/instanceReview.ps1`

**Version Increments:**

- `patch`: Bug fixes and minor changes (4.3.48 → 4.3.49)
- `minor`: New features, backward compatible (4.3.48 → 4.4.0)
- `major`: Breaking changes (4.3.48 → 5.0.0)

**Example:**

```bash
# For a bug fix release
make release bump=patch

# For a new feature release
make release bump=minor

# For a breaking change release
make release bump=major
```

### Step 2: Push to Trigger Release

Commit the version bump, create a GitHub release/tag, and push:

```bash
git push --follow-tags
```

## Release Workflow

When a release is created on GitHub, the `.github/workflows/release.yaml` workflow automatically:

1. **Builds Collection Scripts**:
   - Runs `make clean && make build-collector`
   - Packages Oracle, SQL Server, MySQL, and PostgreSQL collection scripts into `.zip` archives and prepares `dma-collection-masker`
2. **Publishes Release Assets**:
   - Attaches the 4 database collector `.zip` archives and `dma-collection-masker` to the GitHub Release

## Release Artifacts

Each release includes the following downloadable artifacts:

- `db-migration-assessment-collection-scripts-oracle.zip`
- `db-migration-assessment-collection-scripts-sqlserver.zip`
- `db-migration-assessment-collection-scripts-mysql.zip`
- `db-migration-assessment-collection-scripts-postgres.zip`
- `dma-collection-masker`

## Versioning Strategy

This project follows [Semantic Versioning](https://semver.org/) (SemVer):

- **MAJOR.MINOR.PATCH** (e.g., 4.3.48)
- Git tags use the format `v{version}` (e.g., `v4.3.48`)

### When to Bump Each Part

**MAJOR** (Breaking Changes):

- Changed command-line argument formats
- Removed support for database versions
- Incompatible changes to collection script output formats

**MINOR** (New Features):

- New database support or new collection queries
- New collection script features or options

**PATCH** (Bug Fixes):

- Bug fixes in existing collection queries or scripts
- Documentation updates
- Security patches

## Testing a Release Locally

Before pushing:

```bash
# Bump version
make release bump=patch

# Build collector packages
make build

# Verify collection scripts and masker in dist/
ls -lh dist/
```

## Additional Resources

- [GitHub Actions Release Workflow](https://github.com/GoogleCloudPlatform/database-assessment/blob/main/.github/workflows/release.yaml)
- [Semantic Versioning](https://semver.org/)
- [UV Documentation](https://github.com/astral-sh/uv)
- [bump-my-version Documentation](https://github.com/callowayproject/bump-my-version)
