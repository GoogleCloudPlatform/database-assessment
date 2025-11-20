# Releases

This document describes the release process for the Database Migration Assessment tool.

## Prerequisites

- Clean, up-to-date copy of the `main` branch
- All tests passing (`make test`)
- All linting checks passing (`make lint`)
- Documentation built successfully (`make docs`)
- Collaborator access to the repository

## Release Process

A release consists of two steps executed from a tested and linted `main` branch:

### Step 1: Bump Version and Build

```bash
make pre-release increment={major/minor/patch}
```

**What this does:**
1. Generates documentation
2. Cleans build artifacts
3. Uses `bump-my-version` to increment the version number
4. Updates version in all relevant files:
   - `pyproject.toml`
   - `uv.lock`
   - `scripts/masker/dma-collection-masker`
   - `scripts/collector/oracle/collect-data.sh`
   - `scripts/collector/mysql/collect-data.sh`
   - `scripts/collector/postgres/collect-data.sh`
   - `scripts/collector/sqlserver/instanceReview.ps1`
5. Builds collection script ZIP files
6. Builds Python wheel

**Version Increments:**
- `patch`: Bug fixes and minor changes (4.3.44 → 4.3.45)
- `minor`: New features, backward compatible (4.3.44 → 4.4.0)
- `major`: Breaking changes (4.3.44 → 5.0.0)

**Example:**
```bash
# For a bug fix release
make pre-release increment=patch

# For a new feature release
make pre-release increment=minor

# For a breaking change release
make pre-release increment=major
```

### Step 2: Push to Trigger Release

```bash
git push --follow-tags
```

**What this does:**
1. Pushes the version bump commit to `main`
2. Pushes the new version tag (e.g., `v4.3.45`)
3. Triggers the GitHub Actions release workflow

**Important:** Only push the version bump commit and tag. Do not push any other changes.

## Release Workflow

When a tag is pushed, the GitHub Actions release workflow automatically:

### 1. Build Collection Scripts
- Packages Oracle, SQL Server, MySQL, and PostgreSQL collection scripts
- Creates ZIP files for each database type
- Uploads as release artifacts

### 2. Build Python Wheel and Source Distribution
- Builds pure Python wheel (`dma-{version}-py3-none-any.whl`)
- Builds source distribution (`dma-{version}.tar.gz`)
- Uses `uv build` for fast, reproducible builds
- Uploads as release artifacts

### 3. Build Standalone Binaries ⭐
- Compiles PyApp-based standalone binaries for multiple platforms
- **Linux (glibc)**: x86_64 and aarch64 (Ubuntu 14.04+, RHEL 7+, Debian 8+)
- **Linux (musl)**: x86_64 (Alpine Linux, static linking)
- **macOS**: x86_64 and Apple Silicon (arm64)
- **Windows**: x86_64
- All binaries are **fully offline** - no internet required at runtime
- Tests binaries in network-isolated containers (Linux)
- Uploads as release artifacts

### 4. Publish Release
- Creates GitHub release with all artifacts
- Includes collection script ZIPs
- Includes Python wheel and sdist
- Includes standalone binaries for all platforms

## Release Artifacts

Each release includes the following downloadable artifacts:

### Collection Scripts (ZIP files)
- `db-migration-assessment-collection-scripts-oracle.zip`
- `db-migration-assessment-collection-scripts-sqlserver.zip`
- `db-migration-assessment-collection-scripts-mysql.zip`
- `db-migration-assessment-collection-scripts-postgres.zip`

### Python Packages
- `dma-{version}-py3-none-any.whl` - Python wheel
- `dma-{version}.tar.gz` - Source distribution

### Standalone Binaries
- `dma-x86_64-linux-gnu` - Linux x86_64 (glibc 2.17+)
- `dma-aarch64-linux-gnu` - Linux ARM64 (glibc 2.17+)
- `dma-x86_64-linux-musl` - Linux x86_64 (Alpine/musl)
- `dma-x86_64-macos` - macOS Intel (10.13+)
- `dma-aarch64-macos` - macOS Apple Silicon (11+)
- `dma-x86_64-windows.exe` - Windows x86_64 (10+)

## Versioning Strategy

This project follows [Semantic Versioning](https://semver.org/) (SemVer):

- **MAJOR.MINOR.PATCH** (e.g., 4.3.44)
- Git tags use the format `v{version}` (e.g., `v4.3.44`)

### When to Bump Each Part

**MAJOR** (Breaking Changes):
- Removed or renamed CLI commands
- Changed command-line argument formats
- Removed support for database versions
- Changed collection script output formats
- Incompatible API changes

**MINOR** (New Features):
- New database support (e.g., adding MariaDB)
- New CLI commands or options
- New collection script features
- Performance improvements
- New readiness check rules

**PATCH** (Bug Fixes):
- Bug fixes in existing functionality
- Documentation updates
- Dependency updates (non-breaking)
- Collection script fixes
- Security patches

## Rollback

If a release has critical issues:

### Option 1: New Patch Release (Recommended)
```bash
# Fix the issue
git commit -m "fix: critical bug in X"

# Create patch release
make pre-release increment=patch
git push --follow-tags
```

### Option 2: Delete Tag and Re-release
```bash
# Delete local tag
git tag -d v4.3.45

# Delete remote tag
git push origin :refs/tags/v4.3.45

# Fix issue and re-release
make pre-release increment=patch
git push --follow-tags
```

**Warning:** Only delete tags that haven't been widely distributed.

## Post-Release Checklist

After pushing the release:

1. ✅ Verify GitHub Actions workflow completes successfully
2. ✅ Check that all artifacts are attached to the GitHub release
3. ✅ Test download and execution of at least one binary
4. ✅ Verify collection script ZIPs extract correctly
5. ✅ Update release notes if needed (GitHub Releases page)
6. ✅ Announce release in appropriate channels

## Troubleshooting

### Build Fails During `make pre-release`

**Solution:**
```bash
make clean
make install
make pre-release increment=patch
```

### Binary Build Fails in CI

**Check:**
- PyApp version compatibility
- Rust toolchain issues
- Cross-compilation setup
- Disk space in GitHub Actions

**Debug:**
- Review GitHub Actions logs
- Look for Cargo build errors
- Check PyApp environment variables

### Version Mismatch

If version numbers don't match across files:

```bash
# Show current version
uv run bump-my-version show current_version

# Manually fix if needed
uv run bump-my-version bump --new-version 4.3.45 patch
```

### Accidental Push

If you accidentally pushed a version bump:

```bash
# Revert the commit (don't delete tag if already released)
git revert HEAD
git push

# Or reset (only if not public yet)
git reset --hard HEAD~1
git push --force
```

## Testing a Release Locally

Before pushing:

```bash
# Build everything
make pre-release increment=patch

# Check version
uv run bump-my-version show current_version

# Verify collection scripts
ls -lh dist/*.zip

# Verify wheel
ls -lh dist/*.whl

# Test wheel installation
uv pip install dist/dma-*.whl
```

## Release Checklist Template

```markdown
## Pre-Release
- [ ] All tests pass: `make test`
- [ ] Linting passes: `make lint`
- [ ] Documentation builds: `make docs`
- [ ] On `main` branch with latest changes
- [ ] No uncommitted changes: `git status`

## Release
- [ ] Run: `make pre-release increment={patch/minor/major}`
- [ ] Review updated version in files
- [ ] Review generated artifacts in `dist/`
- [ ] Commit looks correct: `git log -1`
- [ ] Tag is correct: `git describe --tags`
- [ ] Push: `git push --follow-tags`

## Post-Release
- [ ] GitHub Actions workflow completed successfully
- [ ] All artifacts present in GitHub release
- [ ] Downloaded and tested one binary
- [ ] Collection scripts download and extract
- [ ] Release notes updated (if needed)
- [ ] Announcement sent (if applicable)
```

## Additional Resources

- [GitHub Actions Release Workflow](../.github/workflows/release.yaml)
- [Semantic Versioning](https://semver.org/)
- [UV Documentation](https://github.com/astral-sh/uv)
- [PyApp Documentation](https://github.com/ofek/pyapp)
- [bump-my-version Documentation](https://github.com/callowayproject/bump-my-version)
