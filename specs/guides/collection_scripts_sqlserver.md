# SQL Server Collection Scripts

**Objective**: This document explains the architecture of the SQL Server collection scripts.

## 1. Core Concept

The SQL Server collection scripts are a set of PowerShell scripts, batch files, and SQL scripts that work together to collect metadata, performance statistics, and configuration information from a SQL Server instance. The main entry point is `runAssessment.bat`, which calls the PowerShell script `instanceReview.ps1`.

## 2. Project-Specific Implementation

The collection process is orchestrated by the `instanceReview.ps1` PowerShell script, which performs the following actions:

1.  **Parses command-line arguments**: The script takes several arguments, including the server name, database name, and authentication information.
2.  **Gathers initial information**: It connects to the `master` database to gather initial information, such as the list of databases to be assessed.
3.  **Executes SQL scripts**: It then iterates through a list of SQL scripts located in the `sql/` directory, executing each one using `sqlcmd`. These scripts collect a wide range of information, including:
    *   Server properties and configuration settings.
    *   Database sizes and properties.
    *   Object lists (tables, views, procedures, etc.).
    *   Index and column information.
    *   User connections and security information.
4.  **Handles Perfmon data**: The script can optionally collect and process Windows Performance Monitor (Perfmon) data using the `dmaSQLServerPerfmonDataset.ps1` script.
5.  **Gathers hardware specs**: It calls `dmaSQLServerHWSpecs.ps1` to collect information about the host machine's hardware.
6.  **Packages the output**: After the collection is complete, the script cleans up the output files, creates a manifest, and compresses the files into a single ZIP archive.

### Pattern

The SQL Server collection scripts follow a **procedural pattern**, orchestrated by the main PowerShell script `instanceReview.ps1`. This script calls a series of other scripts and commands in a specific sequence to perform the collection.

### Code Example

Here is a snippet from `instanceReview.ps1` that shows how the SQL scripts are executed:

```powershell
### Iterate through collections that could execute against multiple databases in the instance
foreach ($databaseName in $dbNameArray) {
    ### Surround the databaseName variable with quotes to protect from values that have spaces in it
    $databaseName = '"{0}"' -f $databaseName
    if ($databaseName -inotmatch "tempdb") {
        WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Object Info for Database $databaseName ..." -logOperation "BOTH"
        sqlcmd -S $serverName -i sql\objectList.sql -d $databaseName -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey database=$databaseName dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" | findstr /v /c:"---" | Add-Content -Path $foldername\$objectList -Encoding utf8
        # ... more sqlcmd calls
    }
}
```

## 3. How to Use

The collection is initiated by running the `runAssessment.bat` script from the command line with the appropriate parameters. For detailed instructions, refer to the `README.txt` file in the `scripts/collector/sqlserver` directory.

## 4. Troubleshooting

-   **Connection errors**: Ensure that the `sqlcmd` executable is in your `PATH` and that the server name and authentication information are correct.
-   **Permissions errors**: The user executing the script needs to have the necessary permissions to access the SQL Server dynamic management views (DMVs) and other system objects. The `createUserForAssessmentWithSQLAuth.bat` and `createUserForAssessmentWithWindowsAuth.bat` scripts are provided to create a user with the required privileges.
-   **PowerShell execution policy**: You may need to adjust your PowerShell execution policy to allow the scripts to run. The `runAssessment.bat` script attempts to do this by using the `-ExecutionPolicy Bypass` flag.
