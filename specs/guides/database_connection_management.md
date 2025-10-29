# Database Connection Management

**Objective**: This document explains how the `dma` tool manages database connections.

## 1. Core Concept

The tool needs to connect to two types of databases:

-   **Source Databases**: The databases that are being assessed (e.g., PostgreSQL, MySQL).
-   **Local Database**: A local DuckDB database used to store the collected data.

## 2. Project-Specific Implementation

### Source Database Connections

The `get_engine` function in `src/dma/lib/db/base.py` is responsible for creating a connection to a source database. It uses `SQLAlchemy` to create a database engine based on the provided `SourceInfo`.

The `SourceInfo` dataclass holds the connection parameters for the source database, such as the database type, username, password, hostname, and port.

### Local Database Connection

The `get_duckdb_connection` function in `src/dma/lib/db/local.py` is a context manager that provides a connection to a local DuckDB database. It automatically handles the creation and cleanup of the connection.

The local database can be either in-memory or a file on disk, depending on the provided `export_path`.

### Pattern

The database connection management is a combination of a **Factory** and a **Context Manager**.

-   The `get_engine` function acts as a **Factory** that creates database engines for different database types.
-   The `get_duckdb_connection` function is a **Context Manager** that ensures that the local database connection is properly closed after use.

### Code Example

Here is an example of how to use the `get_engine` function:

```Python
from dma.lib.db.base import SourceInfo, get_engine

src_info = SourceInfo(
    db_type="POSTGRES",
    username="user",
    password="password",
    hostname="localhost",
    port=5432,
)

engine = get_engine(src_info, database="mydb")
```

Here is an example of how to use the `get_duckdb_connection` function:

```Python
from dma.lib.db.local import get_duckdb_connection

with get_duckdb_connection() as local_db:
    # ... use the local_db connection
```

## 3. How to Use

To connect to a new source database type, you need to:

1.  Add a new condition to the `get_engine` function in `src/dma/lib/db/base.py` to handle the new database type.
2.  Install the necessary database driver.

## 4. Troubleshooting

-   **Driver not found**: Ensure that the required database driver is installed (e.g., `psycopg2` for PostgreSQL).
-   **Authentication errors**: Double-check the username and password for the source database.
