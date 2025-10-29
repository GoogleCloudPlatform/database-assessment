# Architecture Guide: dma

**Last Updated**: 2025-10-29

## Overview

dma is built using a Service-Repository pattern.

## Project Structure

```
src/dma/
├── cli/
├── collector/
│   ├── query_managers/
│   ├── sql/
│   ├── util/
│   └── workflows/
├── lib/
│   └── db/
│       └── adapters/
├── __about__.py
├── __init__.py
├── __main__.py
├── py.typed
├── types.py
└── utils.py
```

## Core Components

*   **`cli`**: Command-line interface using Click.
*   **`collector`**: Core logic for collecting data from databases.
    *   **`query_managers`**: Manages database queries for different database vendors.
    *   **`workflows`**: Defines the steps for data collection.
*   **`lib`**: Shared library code.
    *   **`db`**: Database abstraction layer.
        *   **`adapters`**: Adapters for different database drivers.

## Design Patterns

*   **Adapter Pattern**: Used for database and external service integration.
*   **Service-Repository Pattern**: The intended architecture for data access.

## Data Flow

1.  The `cli` initiates a data collection `workflow`.
2.  The `workflow` uses a `query_manager` to execute SQL queries.
3.  The `query_manager` uses a `db` adapter to connect to the database.
4.  Data is collected and stored for analysis.
