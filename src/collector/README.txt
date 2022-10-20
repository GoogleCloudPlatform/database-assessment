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
      * DBA_ALL_TABLES
      * DBA_DATA_FILES
      * DBA_EXTERNAL_TABLES
      * DBA_FREE_SPACE
      * DBA_HIST_ACTIVE_SESS_HISTORY
      * DBA_HIST_SYS_TIME_MODEL
      * DBA_HIST_DATABASE_INSTANCE
      * DBA_HIST_OSSTAT
      * DBA_HIST_PDB_INSTANCE
      * DBA_HIST_SEG_STAT
      * DBA_HIST_SEG_STAT_OBJ
      * DBA_HIST_SNAPSHOT
      * DBA_HIST_SQLSTAT
      * DBA_HIST_SYS_TIME_MODEL
      * DBA_IND_PARTITIONS
      * DBA_IND_SUBPARTITIONS
      * DBA_INDEXES
      * DBA_LOBS
      * DBA_LOB_PARTITIONS
      * DBA_LOB_SUBPARTITIONS
      * DBA_MVIEWS
      * DBA_MVIEW_LOGS
      * DBA_NESTED_TABLES
      * DBA_OBJECTS
      * DBA_PART_INDEXES
      * DBA_PART_KEY_COLUMNS
      * DBA_PART_TABLES
      * DBA_PROCEDURES
      * DBA_RECYCLEBIN
      * DBA_SEGMENTS
      * DBA_TAB_COLS
      * DBA_TABLESPACES
      * DBA_TAB_PARTITIONS
      * DBA_TAB_SUBPARTITIONS
      * DBA_TEMP_FILES
      * DBA_USERS
      * GV_$DATABASE
      * GV_$INSTANCE
      * GV_$OSSTAT
      * V_$DATABASE
      * V_$INSTANCE
      * V_$PARAMETER
      * V_$SESSION
      * V_$SQL_MONITOR

    Packages:
      * DBMS_SQLTUNE.REPORT_SQL_MONITOR (11g) / DBMS_SQL_MONITOR.REPORT_SQL_MONITOR (12c+)


2. Preparation
--------------

    a) unzip the install archive. A "collection" subdirectory will be created.

    b) review the collector_env.sql configuration file and edit as required.

       Notes:
          1) a number of configurable options are defined and documented in this file
          2) default values are provided as a guide (the utility is able to run with these default options)
          3) ensure that the location specified by the opdba_advisor_spool_dir parameter has sufficient space to
             save extracted data


3. Execution
------------

    a) change directory to the "collection" subdirectory.

    b) login to sqlplus as a user with the required privileges and run:

        @collection.sql

    c) follow the prompt at the end of the warning message to either continue or cancel the execution

        Notes:
            1) Google Database Migration Advisor Data Extractor extracts data for a single database or PDB at a time. In multitenant
               CDB databases, you must either connect to the required PDB container directly or switch to the
               the required PDB container from within your session before running the collector.sql
               script. Running this from within the root container will generate an exception and terminate


4. Results
----------

    An archive of the extracted results will be created in the location specified by the opdba_advisor_spool_dir
    configuration parameter. The archive will be named opdb_[DBNAME]_[DATE_TIME].tgz.

LICENSE_TEXT
