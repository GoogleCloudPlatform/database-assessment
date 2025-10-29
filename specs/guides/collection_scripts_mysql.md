# MySQL Collection Scripts

**Objective**: This document explains the architecture of the MySQL collection scripts.

## 1. Core Concept

The MySQL collection scripts are a set of shell scripts and SQL scripts that work together to collect metadata and performance statistics from a MySQL database. The main script is `collect-data.sh`, which uses the `mysql` command-line client to execute a series of SQL scripts.

## 2. Project-Specific Implementation

The main entry point for the MySQL collection is the `collect-data.sh` shell script. This script performs the following actions:

1.  **Parses command-line arguments**: The script takes several arguments, including the database connection string.
2.  **Connects to the database**: It uses the `mysql` client to connect to the database and runs `sql/init.sql` to get the server UUID.
3.  **Determines the script path**: It runs `sql/_base_path_lookup.sql` to determine the correct subdirectory for version-specific scripts (e.g., `5.7/` or `base/`).
4.  **Executes SQL scripts**: It then iterates through the SQL files in the `sql/` directory and the version-specific subdirectory, executing each one to collect data.
5.  **Collects machine specs**: It calls the `db-machine-specs.sh` script to gather information about the host machine.
6.  **Packages the output**: After the collection is complete, the `collect-data.sh` script cleans up the output files, creates a manifest, and compresses the files into a single archive.

### Pattern

The MySQL collection scripts follow a **procedural pattern**. The `collect-data.sh` script is the main procedure, which calls a series of sub-procedures (the SQL scripts) in a specific order.

### Code Example

Here is a snippet from `collect-data.sh` that shows how the SQL scripts are executed:

```bash
function executeOPMysql {
connectString="$1"
# ...
export DMA_SOURCE_ID=$(${SQLCMD} --user=$user --password=$pass -h $host -P $port --force --silent --skip-column-names $db 2>>${OUTPUT_DIR}/opdb__stderr_${V_FILE_TAG}.log < sql/init.sql | tr -d '\r')
export SCRIPT_PATH=$(${SQLCMD} --user=$user --password=$pass -h $host -P $port --force --silent --skip-column-names $db 2>>${OUTPUT_DIR}/opdb__stderr_${V_FILE_TAG}.log < sql/_base_path_lookup.sql | tr -d '\r')

for f in $(ls -1 sql/*.sql | grep -v -e init.sql | grep -v -e _base_path_lookup.sql)
do
  fname=$(echo ${f} | cut -d '/' -f 2 | cut -d '.' -f 1)
    ${SQLCMD} --user=$user --password=$pass -h $host -P $port --force --table  ${db} >${OUTPUT_DIR}/opdb__mysql_${fname}__${V_TAG} 2>>${OUTPUT_DIR}/opdb__stderr_${V_FILE_TAG}.log  <<EOF
SET @DMA_SOURCE_ID='${DMA_SOURCE_ID}' ;
SET @DMA_MANUAL_ID='${V_MANUAL_ID}' ;
SET @PKEY='${V_FILE_TAG}';
source ${f}
exit
EOF
# ...
done
# ...
}
```

## 3. How to Use

The `collect-data.sh` script is executed from the command line with the appropriate connection parameters. For detailed instructions, refer to the `README.txt` file in the `scripts/collector/mysql` directory.

## 4. Troubleshooting

-   **Connection errors**: Ensure that the `mysql` executable is in your `PATH` and that the connection string is correct.
-   **SQL errors**: Check the log files in the `log` directory for any errors reported by the SQL scripts.
-   **Permissions errors**: The user executing the script needs to have the necessary privileges to access the `information_schema` and other system tables.
