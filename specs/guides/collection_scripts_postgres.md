# PostgreSQL Collection Scripts

**Objective**: This document explains the architecture of the PostgreSQL collection scripts.

## 1. Core Concept

The PostgreSQL collection scripts are a set of shell scripts and SQL scripts that work together to collect metadata and performance statistics from a PostgreSQL database. The main script is `collect-data.sh`, which uses the `psql` command-line client to execute a series of SQL scripts.

## 2. Project-Specific Implementation

The main entry point for the PostgreSQL collection is the `collect-data.sh` shell script. This script performs the following actions:

1.  **Parses command-line arguments**: The script takes several arguments, including the database connection string and a flag (`--allDbs`) to collect from all databases in the instance.
2.  **Connects to the database**: It uses the `psql` client to connect to the database.
3.  **Executes SQL scripts**: The `executeOPPg` function in the script calls `sql/op_collect.sql`, which in turn executes a series of individual SQL scripts to gather the data. The script dynamically chooses version-specific SQL files (e.g., from `sql/12/` or `sql/13/`) based on the database version.
4.  **Collects machine specs**: It calls the `db-machine-specs.sh` script to gather information about the host machine.
5.  **Iterates over all databases (optional)**: If the `--allDbs Y` flag is used, the script will query the list of databases and re-run itself for each database.
6.  **Packages the output**: After the collection is complete, the `collect-data.sh` script cleans up the output files, creates a manifest, and compresses the files into a single archive.

### Pattern

The PostgreSQL collection scripts follow a **procedural pattern**. The `collect-data.sh` script is the main procedure, which calls a series of sub-procedures (the SQL scripts) in a specific order. It also uses recursion when the `--allDbs Y` flag is provided.

### Code Example

Here is a snippet from `collect-data.sh` that shows how the SQL scripts are executed:

```bash
function executeOPPg {
connectString="$1"
# ...
export PGPASSWORD="$pass"
${SQLCMD} -X --user=${user} -d "${db}" -h ${host} -w -p ${port}  --no-align --echo-errors 2>output/opdb__stderr_${V_FILE_TAG}.log <<EOF
\set VTAG ${V_FILE_TAG}
\set PKEY '\'${V_FILE_TAG}\''
\set DMA_SOURCE_ID '\'${DMA_SOURCE_ID}\''
\set DMA_MANUAL_ID '\'${V_MANUAL_ID}\''
\set VPGVERSION ${V_PGVERSION}
\i sql/op_collect.sql
EOF
# ...
}
```

## 3. How to Use

The `collect-data.sh` script is executed from the command line with the appropriate connection parameters. For detailed instructions, refer to the `README.txt` file in the `scripts/collector/postgres` directory.

## 4. Troubleshooting

-   **Connection errors**: Ensure that the `psql` executable is in your `PATH` and that the connection string is correct. The `PGPASSWORD` environment variable is used for authentication.
-   **SQL errors**: Check the log files in the `log` directory for any errors reported by the SQL scripts.
-   **Permissions errors**: The user executing the script needs to have the necessary privileges to access the system catalogs (`pg_catalog`) and other statistics views.
