# Getting Started with the Database Migration Assessment (DMA) Collector

These instructions will guide you through setting up and running the DMA collector using the Python CLI.

## Verify Python Version

The DMA collector requires Python 3.9 or higher. Check your Python version by opening a terminal and running:

```bash
python3 --version
```

If your Python version is lower than 3.9, you'll need to install a compatible version.

## Create a Virtual Environment (Recommended)

A virtual environment isolates the DMA collector's dependencies from other Python projects. This prevents conflicts and ensures a consistent environment.

### Create the virtual environment

To create the new virtual environment.

```bash
python3 -m venv .venv
```

Activate the virtual environment by running:

```bash
source .venv/bin/activate
```

(You'll typically see the virtual environment name in parentheses at the beginning of your terminal prompt: `(.venv) $`)

## Install the DMA Readiness Check Utility

Navigate to the directory containing the DMA collector wheel file (.whl file). This file is the packaged distribution of the collector.

Install the wheel file using pip:

```shell
pip install dma-collector-<version>.whl
```

**Note** Replace `<version>` with the actual version number of the wheel file (e.g., dma-collector-1.2.3.whl).

## Executing the Postgres Readiness Check

Now that the DMA collector is installed, you can run the readiness check for Postgres.

```shell
dma readiness-check --db-type postgres --hostname localhost --no-prompt --port 5432 --database postgres --username postgres --password password1
```

If you do not supply credentials at the CLI, the tool will prompt you for connection information.


