README
======
Instructions on how to prepare and run Google Database Migration Advisor Data Extractor to extract the data required
for analysis by Database Migration Advisor.

1. Background
-------------

    This utility extracts metadata about the tables, partitions and SQL workload in a database into CSV files.
    These CSV files are then used by Database Migration Advisor internally to analyze the data with Google Database Migration Advisor.

    a) License Requirements
    -----------------------
    !!! IMPORTANT !!! Google Database Migration Advisor accesses DBA_HIST% views that are licensed
    separately under the Oracle Diagnostics Pack and DBMS_SQLTUNE/DBMS_SQL_MONITOR packages
    to generate Real-Time SQL Monitoring reports that are licensed separately under the
    Oracle Tuning Pack. Please ensure you have the correct licenses to run this utility.

    b) Database Privileges
    ----------------------
    This utility must be run as a database user with privileges to SELECT from the views 
    and to execute the packages listed below:

    Views:

      * AUX_STATS$
      * CDB_CONSTRAINTS
      * CDB_DATA_FILES
      * CDB_DB_LINKS
      * CDB_EXTERNAL_TABLES
      * CDB_FEATURE_USAGE_STATISTICS
      * CDB_FREE_SPACE
      * CDB_HIGH_WATER_MARK_STATISTICS
      * CDB_HIST_ACTIVE_SESS_HISTORY
      * CDB_HIST_IOSTAT_FUNCTION
      * CDB_HIST_OSSTAT
      * CDB_HIST_SNAPSHOT
      * CDB_HIST_SQLSTAT
      * CDB_HIST_SQLTEXT
      * CDB_HIST_SYSMETRIC_HISTORY
      * CDB_HIST_SYSMETRIC_SUMMARY
      * CDB_HIST_SYSSTAT
      * CDB_HIST_SYSTEM_EVENT
      * CDB_HIST_SYS_TIME_MODEL
      * CDB_INDEXES
      * CDB_OBJECTS
      * CDB_PART_TABLES
      * CDB_PDBS
      * CDB_SEGMENTS
      * CDB_SERVICES
      * CDB_SOURCE
      * CDB_TAB_COLUMNS
      * CDB_TABLES
      * CDB_TABLESPACES
      * CDB_TAB_PARTITIONS
      * CDB_TAB_SUBPARTITIONS
      * CDB_USERS
      * DBA_CONSTRAINTS
      * DBA_CPU_USAGE_STATISTICS
      * DBA_DATA_FILES
      * DBA_DB_LINKS
      * DBA_EXTERNAL_TABLES
      * DBA_FEATURE_USAGE_STATISTICS
      * DBA_FREE_SPACE
      * DBA_HIGH_WATER_MARK_STATISTICS
      * DBA_HIST_ACTIVE_SESS_HISTORY
      * DBA_HIST_IOSTAT_FUNCTION
      * DBA_HIST_OSSTAT
      * DBA_HIST_SNAPSHOT
      * DBA_HIST_SQLSTAT
      * DBA_HIST_SQLTEXT
      * DBA_HIST_SYSMETRIC_HISTORY
      * DBA_HIST_SYSMETRIC_SUMMARY
      * DBA_HIST_SYSSTAT
      * DBA_HIST_SYSTEM_EVENT
      * DBA_HIST_SYS_TIME_MODEL
      * DBA_INDEXES
      * DBA_OBJECTS
      * DBA_PART_TABLES
      * DBA_REGISTRY_SQLPATCH
      * DBA_SEGMENTS
      * DBA_SERVICES
      * DBA_SOURCE
      * DBA_TAB_COLUMNS
      * DBA_TABLES
      * DBA_TABLESPACES
      * DBA_TAB_PARTITIONS
      * DBA_TAB_SUBPARTITIONS
      * DBA_USERS
      * GV_$ARCHIVE_DEST
      * GV_$ARCHIVED_LOG
      * GV_$INSTANCE
      * GV_$PARAMETER
      * LOGSTDBY$SKIP_SUPPORT
      * NLS_DATABASE_PARAMETERS
      * REGISTRY$HISTORY
      * V_$DATABASE
      * V_$DIAG_ALERT_EXT
      * V_$INSTANCE
      * V_$LOG
      * V_$LOG_HISTORY
      * V_$PDBS
      * V_$PGASTAT
      * V_$RMAN_BACKUP_JOB_DETAILS
      * V_$SGASTAT
      * V_$SQLCOMMAND
      * V_$TEMP_SPACE_HEADER
      * V_$VERSION


2. Preparation
--------------

    a) Unzip the install archive. A "collector" subdirectory will be created.

    b) Ensure sqlplus is in the path.

    c) If the exract will be run by a user that does not have SYSDBA privilege, connect to the database 
       as a user with SYSDBA privileges and execute grants_wrapper.sql.  You will be prompted for the
       name of a database user to be granted SELECT privileges on the objects required for data collection.


3. Execution
------------

    a) Change directory to the "collector" subdirectory.

    b) Execute ./collect-data.sh, passing a database connection string as the only parameter:

        ./collect-data.sh 'username/password@//hostname.domain.com:1521/dbname.domain.com as sysdba'

    c) Follow the prompt at the end of the warning message to either continue or cancel the execution

        Notes:
            1) Google Database Migration Advisor Data Extractor extracts data for the entire database. In multitenant
               CDB databases, you must connect to the container database.  Running this from within a 
               pluggable database will not collect the proper data.


4. Results
----------

    An archive of the extracted results will be created in the directory collector/output. 
    The full path and file name will be displayed on completion.


5. License
------------
Copyright 2022 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

