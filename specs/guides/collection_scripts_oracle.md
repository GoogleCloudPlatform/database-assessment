# Oracle Collection Scripts

**Objective**: This document explains the architecture of the Oracle collection scripts.

## 1. Core Concept

The Oracle collection scripts are a set of shell scripts and SQL scripts that work together to collect metadata and performance statistics from an Oracle database. The main script is `collect-data.sh`, which uses `sqlplus` to execute a series of SQL scripts.

## 2. Project-Specific Implementation

The main entry point for the Oracle collection is the `collect-data.sh` shell script. This script performs the following actions:

1.  **Parses command-line arguments**: The script takes several arguments, including the database connection string and an option to use the Oracle Diagnostics Pack.
2.  **Connects to the database**: It uses `sqlplus` to connect to the database and runs `op_collect_init.sql` to set up the environment.
3.  **Executes the main collection script**: It then calls `op_collect.sql`, which is the main script that orchestrates the data collection.
4.  **Executes individual SQL scripts**: `op_collect.sql` calls a series of individual SQL scripts located in the `sql/extracts` directory. Each of these scripts is responsible for collecting a specific piece of information (e.g., `dbobjects.sql`, `sourcecode.sql`).
5.  **Handles different data collection scenarios**: The script has logic to handle different scenarios, such as whether to use the Oracle Diagnostics Pack (`usediagnostics`) or Statspack (`nodiagnostics`).
6.  **Packages the output**: After the collection is complete, the `collect-data.sh` script cleans up the output files, creates a manifest, and compresses the files into a single archive.

### Pattern

The Oracle collection scripts follow a **procedural pattern**. The `collect-data.sh` script is the main procedure, which calls a series of sub-procedures (the SQL scripts) in a specific order.

### Code Example

Here is a snippet from `collect-data.sh` that shows how the main collection script is executed:

```bash
function executeOP {
connectString="$1"
OpVersion=$2
DiagPack=$(echo $3 | tr [[:upper:]] [[:lower:]])
manualUniqueId="${4}"
statsWindow=${5}

if ! [ -x "$(command -v ${SQLPLUS})" ]; then
  echo "Could not find ${SQLPLUS} command. Source in environment and try again"
  echo "Exiting..."
  exit 1
fi


${SQLPLUS} -s /nolog << EOF
SET DEFINE OFF
connect ${connectString}
@${SQL_DIR}/op_collect.sql ${OpVersion} ${SQL_DIR} ${DiagPack} ${V_TAG} ${SQLOUTPUT_DIR} "${manualUniqueId}" ${statsWindow}
exit;
EOF

}
```

## 3. How to Use

The `collect-data.sh` script is executed from the command line with the appropriate connection parameters. For detailed instructions, refer to the `README.txt` file in the `scripts/collector/oracle` directory.

## 4. Troubleshooting

-   **Connection errors**: Ensure that the `sqlplus` executable is in your `PATH` and that the connection string is correct.
-   **SQL errors**: Check the log files in the `log` directory for any errors reported by the SQL scripts.
-   **Permissions errors**: The user executing the script needs to have the necessary privileges to access the Oracle data dictionary views. The `sql/setup/grants_wrapper.sql` script can be used to grant the required privileges.
