# Database Migration Service (DMS): Migration Job Validation Report (Oracle to PostgreSQL) Overview

The Database Migration Service: Migration Job Validation Report (Oracle to PostgreSQL) is a SQL script designed to analyze a source Oracle database and identify potential compatibility issues or necessary adjustments before migrating table data to Google Cloud SQL for PostgreSQL or AlloyDB for PostgreSQL.

## Purpose

The script checks various aspects of an Oracle database against the [requirements](https://cloud.google.com/database-migration/docs/oracle-to-postgresql/configure-source-database) and [known limitations and recommendations](https://cloud.google.com/database-migration/docs/oracle-to-postgresql/known-limitations) for migrating data to PostgreSQL using DMS. 

Most of the checks are performed in DMS itself when a Migration Job is validated by running a test before starting the job. Some of the checks the script performs are not currently checked within DMS. 

The benefit of abstracting these checks into this SQL script and running it *before* initiating a DMS Migration Job are twofold:

1. Speed: the only requirements are access to the source Oracle database
2. Scale: the script can be executed across the full set of in scope databases and results collated

This can help to proactively address problems ensuring a smoother migration process. 

> The scope of the validation is limited to a DMS Migration Job which is used to migrate table data only. This script is not designed to check for potential errors during procedural code conversion in a DMS Conversion Workspace. Additionally, as it only connects to the source database, no validation of the target database is performed.

## What it checks

The SQL script performs the following checks:

* **Archive log mode:** Verifies the database is in `ARCHIVELOG` mode
* **Archive log count:** Verifies there are archive logs present in the archive destination
* **User privileges / permissions:** Verifies the correct privileges and permissions have been granted to the user in the source DMS Oracle connection profile
* **Supplemental logging (minimal):** Verifies the correct minimal supplemental logging configuration
* **Supplemental logging (objects):** Verifies the correct object supplemental logging configuration in the schema(s) to be migrated
* **Unsupported character set:** Verifies the database is using a supported character set
* **Oracle Autonomous Database:** Verifies the database is not an Oracle Autonomous Database
* **Unsupported object names:** Verifies object names in the schema(s) to be migrated do not contain unsupported characters
* **Oracle hidden column names:** Verifies Oracle hidden column names due to: function-based indexes, extended statistics, custom types and LOBs in the schema(s) to be migrated
* **Unsupported column names:** Verifies column names in the schema(s) to be migrated do not contain unsupported characters
* **Index-organized tables (IOTs):** Verifies there are no IOTs in the schema(s) to be migrated
* **Tables without primary keys:** Verifies tables have primary keys in the schema(s) to be migrated
* **Oracle Label Security (OLS):** Verifies if OLS is in use (ORACLE LABEL SECURITY OPTION ENABLED ONLY)
* **Unsupported data types with NOT NULL constraints:** Verifies unsupported data types with `NOT NULL` constraints in the schema(s) to be migrated
* **Unsupported data types without NOT NULL constraints:** Verifies unsupported data types without `NOT NULL` constraints in the schema(s) to be migrated 
* **Count of tables to be migrated:** Verifies the count of all tables in the schema(s) to be migrated
* **Global temporary tables:** Verifies global temporary tables in the schema(s) to be migrated
* **DBMS_JOB or DBMS_SCHEDULER jobs:** Verifies `DBMS_JOB` or `DBMS_SCHEDULER` jobs in the schema(s) to be migrated 
* **Materialized views:** Verifies materialized views in the schema(s) to be migrated 
* **Sequences:** Verifies sequences in the schema(s) to be migrated 
* **XMLType tables:** Verifies `XMLType` tables in the schema(s) to be migrated 
* **Object tables:** Verifies Object tables in the schema(s) to be migrated 
* **Namespace clashes:** Verifies table and constraint namespace clashes in the schema(s) to be migrated 
* **LogMiner: table and column name lengths:** Verifies Logminer 30 character table and column name lengths in the schema(s) to be migrated

## Output

The SQL script outputs a clear report in either text or HTML format listing each check with a severity level:

* **Action required:** Action is necessary for a successful migration
* **No issues:** The check passed, no action needed
* **Review recommended:** Potential issue or recommendation; review is advised. May require adjustments depending on migration specifics
* **Information only:** An item to be aware of but may require no action

Each finding includes a description and where appropriate an action that often links to relevant Google Cloud documentation for more details on how to address it.

## Required privileges

The SQL script must be run as a database user with the following privileges:

`SELECT` from

  * `CDB_ROLE_PRIVS` (MULTITENANT ONLY)
  * `CDB_SYS_PRIVS` (MULTITENANT ONLY)
  * `CDB_TABLES` (MULTITENANT ONLY)
  * `CDB_TAB_PRIVS` (MULTITENANT ONLY)
  * `CDB_USERS` (MULTITENANT ONLY)
  * `DBA_CONSTRAINTS`
  * `DBA_IND_COLUMNS`
  * `DBA_IND_EXPRESSIONS`
  * `DBA_JOBS`
  * `DBA_LOBS`
  * `DBA_LOG_GROUPS`
  * `DBA_MVIEWS`
  * `DBA_OBJECT_TABLES`
  * `DBA_OLS_STATUS` (ORACLE LABEL SECURITY ENABLED ONLY)
  * `DBA_ROLE_PRIVS`
  * `DBA_SCHEDULER_JOBS`
  * `DBA_SEQUENCES`
  * `DBA_SUPPLEMENTAL_LOGGING`
  * `DBA_SYS_PRIVS`
  * `DBA_TABLES`
  * `DBA_TAB_COLS`
  * `DBA_TAB_COLUMNS`
  * `DBA_TAB_PRIVS`
  * `DBA_TYPES`
  * `DBA_USERS` (NON-MULTITENANT ONLY)
  * `DBA_VIEWS`
  * `DBA_XML_TABLES`
  * `NLS_DATABASE_PARAMETERS`
  * `V$ARCHIVED_LOG`
  * `V$DATABASE`
  * `V$INSTANCE`
  * `V$PDBS` (MULTITENANT ONLY)

`EXECUTE` on

  * `DBMS_OUTPUT`
  * `DBMS_SQL`
  * `DBMS_DB_VERSION`
  * `DBMS_APPLICATION_INFO`

## Version support

Oracle versions 11g and above are supported.

## Execution

The script makes use of SQL*Plus functionality and as such that is the only supported client.

Run as a normal SQL*Plus script either via a command line invocation:

```
sqlplus <username>/<password>@//<hostname>:<port>/<service_name> @dms_migration_job_validator.sql
```

or at the SQL*Plus prompt after logging on

```
SQL> @dms_migration_job_validator.sql
```

The script prompts for the following information:

```
Enter the names of the schema(s) to be migrated (csv) (default=ALL non-Oracle) : 
Enter the username used in the source Oracle connection profile                :
Enter the PDB name (multitenant databases only) (default=None)                 :
Enter the format for the generated report (TEXT or HTML, default=HTML)         : 
```
To accept the default value press enter.

An example set of inputs against a multitenant database:

```
Enter the names of the schema(s) to be migrated (csv) (default=ALL non-Oracle) : APP1,APP2,APP3 
Enter the username used in the source Oracle connection profile                : C##DMS_USER
Enter the PDB name (multitenant databases only) (default=None)                 : MYPDB
Enter the format for the generated report (TEXT or HTML, default=HTML)         : 
```

The report is generated in the current working directory.

# Feedback

Raise issues and feature requests at the [database-assessment](https://github.com/GoogleCloudPlatform/database-assessment/issues) GitHub repository.

# Changelog

## v1.1 (22 May 2025)

* Fix bug causing User privileges / permissions check to execute test code
* Expand list of excluded Oracle internal users (applicable to all schema related checks)
* Exclude materialized view log tables (`MLOG$`) from unsupported column list check
* Report internal hidden columns (e.g. `SYS_NC12345$`) as separate check
* List materialized views by name rather than a count by schema
* Add database version to report metadata section
* Minor changes to descriptions and/or actions
* Update required privileges section of this readme

## v1.0 (12 May 2025)

* Initial release