# Collector Architecture

**Objective**: This document explains the architecture of the data collector component.

## 1. Core Concept

The data collector is responsible for connecting to source databases, executing queries to gather information, and storing the results in a local DuckDB database. The collector is designed to be extensible to support different database types.

## 2. Project-Specific Implementation

The collector's architecture is based on two main components: **Workflows** and **Query Managers**.

### Workflows

Workflows are high-level classes that orchestrate the data collection process. They are responsible for:

-   Initializing the local DuckDB database.
-   Calling the appropriate Query Manager to execute queries.
-   Importing the query results into DuckDB.
-   Exporting the collected data.

The base class for all workflows is `BaseWorkflow` in `src/dma/collector/workflows/base.py`.

### Query Managers

Query Managers are responsible for managing and executing the SQL queries for a specific database type. They are designed to be database-specific, with a separate Query Manager for each supported database (e.g., `PostgresQueryManager`, `MySqlQueryManager`).

The base class for all query managers is `CanonicalQueryManager` and `CollectionQueryManager` in `src/dma/collector/query_managers/base.py`.

### Pattern

The collector uses a **Strategy Pattern**. The `BaseWorkflow` is the context, and the `CollectionQueryManager` is the strategy. The `BaseWorkflow` is configured with a specific `CollectionQueryManager` at runtime, depending on the type of the source database. This allows the collector to support different database types without changing the core workflow logic.

### Code Example

Here is a simplified example of how a workflow and query manager interact:

```Python
# In a workflow class
from dma.collector.query_managers.postgres import PostgresQueryManager

class MyWorkflow(BaseWorkflow):
    def execute(self) -> None:
        # ...
        query_manager = PostgresQueryManager(connection=self.src_db)
        results = query_manager.execute_collection_queries()
        self.import_to_table(results)
        # ...
```

## 3. How to Use

To add support for a new database type, you need to:

1.  Create a new `QueryManager` class in `src/dma/collector/query_managers/`.
2.  Create a new directory with the SQL queries for the new database type in `src/dma/collector/sql/`.
3.  Create a new workflow class in `src/dma/collector/workflows/` that uses the new `QueryManager`.
4.  Update the CLI to add a new option for the new database type.

## 4. Troubleshooting

-   **SQL errors**: Check the SQL queries in the corresponding `src/dma/collector/sql/` directory for syntax errors.
-   **Connection errors**: Ensure that the database connection parameters are correct and that the user has the necessary permissions.
