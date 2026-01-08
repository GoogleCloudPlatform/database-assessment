# UV Configuration for Internal Environments

This document outlines how to configure `uv` to handle package index conflicts, specifically for developers working in environments with restricted or authenticated internal registries (like Google's Rodete).

## The Problem

In some internal environments, the system might be configured to use a private package registry by default. This can lead to:
1.  **Authentication Errors (401):** If `uv` or `pip` tries to access the internal registry without valid `keyring` credentials.
2.  **Missing Packages:** Internal registries may not mirror the entire public PyPI, leading to resolution failures for standard tools like `setuptools`.

## The Solution: Local Override

To ensure `uv` always uses the public PyPI for this project without affecting the shared repository configuration, use a local `uv.toml` file.

### 1. Create `uv.toml`

Create a file named `uv.toml` in the project root with the following content:

```toml
[[index]]
name = "pypi"
url = "https://pypi.org/simple"
default = true
```

This forces `uv` to treat the public PyPI as the primary source for all dependency resolutions.

### 2. Ignore the File

Ensure `uv.toml` is added to your `.gitignore` so it doesn't get committed to the repository:

```text
# Local uv configuration
uv.toml
```

## Automated Setup

The project includes a helper script and Makefile integration to automate this for users on supported distributions.

### Using the Makefile

Run the following command to reset your environment and automatically configure the local index if you are on a "Rodete" system:

```bash
make install
```

### Manual Script Execution

You can also run the setup script directly:

```bash
./tools/setup-local-env.sh
```

## Sharing Context with Gemini

If you are using the Gemini CLI and want it to remember this preference across different projects, you can add a rule to your global configuration at `~/.gemini/python.md`:

```markdown
## UV Index Preference
When working in internal environments (detectable via `/etc/os-release` containing 'rodete'), 
prefer creating a local `uv.toml` that forces `https://pypi.org/simple` as the default index 
to avoid 401 errors or package resolution failures.
```
