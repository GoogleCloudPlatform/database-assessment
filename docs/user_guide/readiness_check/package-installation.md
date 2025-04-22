# Getting Started with the Database Migration Assessment (DMA) Collector

These instructions will guide you through setting up and running the DMA collector using the Python CLI.

## Verify Python Version

The DMA collector requires Python 3.9 or higher. Check your Python version by opening a terminal and running:

```bash
python3 --version
```

If your Python version is lower than 3.9, you'll need to install a compatible version.

## Download the latest Python wheel

This command uses `curl`, `grep`, and `cut` to find and download the latest `.whl` package file from the project's GitHub releases page.

```bash
curl -sL https://api.github.com/repos/GoogleCloudPlatform/database-assessment/releases/latest | grep '"browser_download_url":' | grep '\.whl"' | cut -d '"' -f 4 | xargs curl -LO
```

*(Note: This command relies on the structure of the GitHub API response. If it fails, or if you need a specific older version, you can manually download the `.whl` file from the [Releases page](https://github.com/GoogleCloudPlatform/database-assessment/releases).)*

## Create a Virtual Environment (Recommended)

A virtual environment isolates the DMA collector's dependencies from other Python projects. This prevents conflicts and ensures a consistent environment.

### Create the virtual environment

Navigate to your desired project directory and run:

```bash
python3 -m venv .venv
```

### Activate the virtual environment

Activate the virtual environment by running:

```bash
source .venv/bin/activate
```

*(Note: You can often identify when you’ve activated the virtual environment in your terminal. When active, you'll typically see the virtual environment name in parentheses at the beginning of your terminal prompt: `(.venv) $`)*

## Install the DMA Readiness Check Utility

Navigate to the directory where you downloaded the DMA collector wheel file (`.whl`).

Install the wheel file using pip. The `[postgres]` extra installs additional libraries required to connect to PostgreSQL databases.

First, identify the exact filename of the downloaded wheel. You can list the files in the current directory:

```bash
ls *.whl
```

Then, use the specific filename in the install command. Replace `<downloaded_wheel_filename>` with the actual name:

```shell
pip install './<downloaded_wheel_filename>[postgres]'
```

*Example: If the downloaded file is `dma-collector-4.3.43-py3-none-any.whl`, the command would be:*

```shell
pip install './dma-collector-4.3.43-py3-none-any.whl[postgres]'
```

*(Note: The `./` prefix indicates the file is in the current directory. Depending on your shell and exact pip version, the quotes surrounding the filename might not be required.)*

## Executing the Postgres Readiness Check

Now that the DMA collector is installed, you can run the readiness check for Postgres.

```shell
dma readiness-check --db-type postgres --hostname localhost --no-prompt --port 5432 --database postgres --username postgres --password password1
```

> **Note:** For credentials, please use the username that you will be using to set up the migration.

If you do not supply credentials at the CLI, the tool will prompt you for connection information.

## Upgrading an existing installation

If you’ve already installed the utility into a virtual environment and would like to update to a newer release:

1. Download the new wheel file (`.whl`) for the desired version from the [Releases page](https://github.com/GoogleCloudPlatform/database-assessment/releases).
2. Ensure your virtual environment is active (`source .venv/bin/activate`).
3. Navigate to the directory containing the new wheel file.
4. Run the install command with the `--upgrade` flag:

```shell
pip install --upgrade 'dma-collector-<new_version>.whl[postgres]'
```

*(Replace `<new_version>` with the actual version number in the filename)*

## Uninstalling

To remove the DMA collector utility and its dependencies, simply deactivate and remove the virtual environment directory:

1. Deactivate the virtual environment (if active):

    ```bash
    deactivate
    ```

2. Remove the virtual environment directory (assuming it's named `.venv` in your current location):

    ```bash
    rm -Rf ./.venv/
    ```
