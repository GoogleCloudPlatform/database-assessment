README
======
Instructions on how to prepare and run Google Database Migration Assessment Data Extractor to extract the data required
for analysis by Database Migration Assessment.

1. Background
-------------

    This utility extracts metadata about the tables, partitions and SQL workload in a database into CSV files.
    These CSV files are then used by Database Migration Assessment internally to analyze the data with Google Database Migration Assessment.

    a) License Requirements
    -----------------------
    !!! IMPORTANT !!! Google Database Migration Assessment accesses DBA_HIST% views that are licensed
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

    a) Unzip the install archive.

    b) Ensure sqlplus is in the path.

    c) If the extract will be run by a user that does not have SYSDBA privilege, connect to the database 
       as a user with SYSDBA privileges and create the user if needed.  If this is a multi-tenant database,
       create the user as a common user in the root container. The Dma_collector does not currently support
       running in individual pluggable databases.

        sqlplus "sys/password@//hostname:port/dbservicename"
        SQL> create user DMA_COLLECTOR identified by password;
        SQL> grant connect, create session to DMA_COLLECTOR;

    d) Execute grants_wrapper.sql.  You will be prompted for the name of a database user 
       (Note that input is case-sensitive and must match the username created above) to be granted 
       privileges on the objects required for data collection.
       You will also be prompted whether or not to allow access to the AWR/ASH data.

    Ex:
        SQL> @grants_wrapper.sql

        SQL> Please enter the DB Local Username(Or CDB Username) to receive all required grants: DMA_COLLECTOR
        SQL> Please enter Y or N to allow or disallow use of the Tuning and Diagnostic Pack (AWR/ASH) data (Y) Y

    e) The grant_wrapper script will grant privileges required and will output a list of what has been granted.

3. Execution
------------

    a) Execute collect-data.sh, passing the database connection string and indicator on whether to use AWR/ASH diagnostic data.

        To use the AWR/ASH data:
        ./collect-data.sh 'username/password@//hostname.domain.com:1521/dbname.domain.com' UseDiagnostics

        To prevent use of AWR/ASH data and use STATSPACK data (if available) instead:
        ./collect-data.sh 'username/password@//hostname.domain.com:1521/dbname.domain.com' NoDiagnostics

        Notes:
            1) Google Database Migration Assessment Data Extractor extracts data for the entire database. In multitenant
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

