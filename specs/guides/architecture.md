# Architecture Guide: dma

**Last Updated**: Thursday, October 31, 2025

## Overview

The `dma` project is a data-intensive Python application designed for database migration assessment. It features a command-line interface (CLI) for data collection and a web server component for serving an API, built on the Litestar framework. The architecture is designed to be modular and extensible, supporting multiple database dialects.

## Project Structure

The project follows a standard `src` layout:

```
collector/
├── src/
│   ├── collector_cli/  # Source for the collector packaging CLI
│   └── dma/            # Main application source code
│       ├── cli/        # Main CLI application logic
│       ├── collector/  # Data collection logic
│       └── lib/        # Core libraries and business logic
├── tests/
│   ├── unit/
│   └── integration/
├── docs/
└── scripts/
    └── collector/      # Shell scripts for data collection
```

## Core Components

-   **`dma.cli`**: The main entry point for the application's command-line interface, built using `click`.
-   **`dma.collector`**: Contains the core logic for connecting to databases and executing assessment queries. It is designed to be database-agnostic where possible.
-   **`dma.lib`**: Contains foundational code, including database connection management, data transformation logic, and core data structures.
-   **`collector_cli`**: A secondary CLI application responsible for packaging the collector scripts for different database targets.
-   **`scripts/collector`**: Contains the raw SQL queries and shell scripts used for data collection, organized by database dialect (Oracle, Postgres, etc.).

## Design Patterns

-   **Service-Repository**: The application separates the high-level business logic (services) from the data access logic (repositories). `aiosql` is used to manage SQL queries in a repository-like pattern, keeping SQL separate from the Python code.
-   **Adapter Pattern**: The collector uses an adapter-like pattern to support different database dialects. Each dialect has its own set of collection scripts and potentially custom connection logic.
-   **Dependency Injection**: The Litestar web server component makes use of dependency injection for managing resources like database connections.

## Data Flow

1.  A user invokes the `dma` CLI or the collector scripts directly.
2.  The collector connects to the target database using the appropriate driver.
3.  SQL queries from the `scripts/collector` directory are executed against the database.
4.  The raw data is collected, processed, and transformed using `polars` and `duckdb`.
5.  The final assessment report is generated.
