# CLI Architecture

**Objective**: This document explains the architecture of the command-line interface (CLI) for the `dma` tool.

## 1. Core Concept

The CLI is the primary user interface for the Database Migration Assessment tool. It is built using the `click` library, which provides a declarative way to create command-line tools. The CLI allows users to initiate data collection and readiness checks.

## 2. Project-Specific Implementation

The main entry point for the CLI is the `app` function in `src/dma/cli/main.py`. This function is decorated with `@group`, which turns it into a container for other commands.

### Pattern

The CLI follows a simple group-command pattern. The main `app` function serves as the group, and individual commands are added to it. Each command is a standalone function decorated with `@app.command()` and is responsible for a specific piece of functionality.

### Code Example

Here is a snippet from `src/dma/cli/main.py` that shows the basic structure:

```Python
import click
from click import group

@group(name="DMA", context_settings={"help_option_names": ["-h", "--help"]})
def app(ctx: Context) -> None:
    """Database Migration Assessment"""

@app.command(
    name="readiness-check",
    # ... other options
)
def readiness_assessment(
    # ... command arguments
) -> None:
    """Process a collection of advisor extracts."""
    # ... command logic
```

## 3. How to Use

To add a new command to the CLI, you need to:

1.  Create a new function in `src/dma/cli/main.py`.
2.  Decorate the function with `@app.command(name="your-command-name")`.
3.  Add any necessary options using the `@click.option()` decorator.
4.  Implement the command logic within the function.

## 4. Troubleshooting

-   **Command not found**: Ensure that the command function is correctly decorated with `@app.command()` and that the `pyproject.toml` is configured to point to the `app` function.
-   **Incorrect arguments**: Double-check the `type` and `help` text for each `@click.option()` to ensure they are correct.
