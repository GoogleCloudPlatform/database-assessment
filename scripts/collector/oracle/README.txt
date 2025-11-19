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
    This utility must be run as a database user with privileges to SELECT from certain data dictionary views.
    The script sql/setup/grants_wrapper.sql is supplied to grant the required privileges.  Instructions for
    exeuting it are below.

    c) System Requirements
    ----------------------
    The collection script depends on the following to be available on the machine from which it is run:
    bash shell

    awk
    cat
    cp
    cut
    date
    dirname
    grep (ggrep on Solaris)
    gzip
    head
    iconv
    locale
    ls
    md5sum (md5 or csum on HP/UX)
    mkdir
    mv
    ps
    pwd
    rm
    sed
    sleep
    sort
    sqlplus
    tail
    tar
    tee
    time
    tr
    uname
    uniq
    wait
    wc
    which
    xargs
    zip

    cygpath (Windows only, if using Cygwin)
    wslpath (Windows only, if using WSL)

2. Preparation
--------------

    a) Unzip the install archive.

    b) Ensure sqlplus is in the path.

    c) If the extract will be run by a user that does not have SYSDBA privilege, connect to the database
       as a user with SYSDBA privileges and create the user if needed.  If this is a multi-tenant database,
       create the user as a common user in the root container. The Dma_collector does not currently support
       running in individual pluggable databases.

       For non-CDB databases:
           sqlplus "sys/password@//hostname:port/dbservicename as sysdba"
           SQL> create user DMA_COLLECTOR identified by password;
           SQL> grant connect, create session to DMA_COLLECTOR;

        For multitenant databases:
           sqlplus "sys/password@//hostname:port/dbservicename as sysdba"
           SQL> create user C##DMA_COLLECTOR identified by password;
           SQL> grant connect, create session to C##DMA_COLLECTOR;

    d) Navigate to the sql/setup directory and execute grants_wrapper.sql as a user with SYSDBA privileges.
       You will be prompted for the name of a database user
       (Note that input is case-sensitive and must match the username created above) to be granted
       privileges on the objects required for data collection.
       You will also be prompted whether or not to allow access to the AWR/ASH data.

       Example for non-CDB databases:
        SQL> @grants_wrapper.sql

        SQL> Please enter the DB Local Username(Or CDB Username) to receive all required grants: DMA_COLLECTOR
        SQL> Please enter Y or N to allow or disallow use of the Tuning and Diagnostic Pack (AWR/ASH) data (Y) Y

       Example for multitenant databases:
        SQL> @grants_wrapper.sql

        SQL> Please enter the DB Local Username(Or CDB Username) to receive all required grants: C##DMA_COLLECTOR
        SQL> Please enter Y or N to allow or disallow use of the Tuning and Diagnostic Pack (AWR/ASH) data (Y) Y

    e) The grant_wrapper script will grant privileges required and will output a list of what has been granted.

3. Execution
------------

    a) Execute collect-data.sh, passing the database connection string and indicator on whether to use AWR/ASH diagnostic data.

       Parameters:

       Connection definition must one of:
           {
             --connectionStr       Oracle EasyConnect string formatted as {user}/{password}@//{db host}:{listener port}/{service name}.
            or
             --hostName            Database server host name.
             --port                Database Listener port.
             --databaseService     Database service name.
             --collectionUserName  Database user name.
             --collectionUserPass  Database password.
           }
       Performance statistics source
           --statsSrc              Required. Must be one of AWR, STATSPACK, NONE.   When using STATSPACK, see note about --statsWindow parameter below.
       Performance statistics window
           --statsWindow           Optional. Number of days of performance stats to collect.  Must be one of 7, 30.  Default is 30.
                                   NOTE: IF STATSPACK HAS LESS THAN 30 DAYS OF COLLECTION DATA, SET THIS PARAMETER TO 7 TO LIMIT TO 1 WEEK OF COLLECTION.
                                   IF STATSPACK HAS BEEN ACTIVATED SPECIFICALLY FOR DMA COLLECTION, ENSURE THERE ARE AT LEAST 8
                                   CALENDAR DAYS OF COLLECTION BEFORE RUNNING THE DMA COLLECTOR.

      Note: If the password has special characters that may be interpreted by the shell, use the --connectionStr option and enclose the entire connection string in single quotes.

      Examples:

        To use the AWR/ASH data:
          ./collect-data.sh --connectionStr '{user}/{password}@//{db host}:{listener port}/{service name}' --statsSrc AWR
         or
          ./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port} --databaseService {service name} --statsSrc AWR


        To use the STATSPACK data:
          ./collect-data.sh --connectionStr '{user}/{password}@//{db host}:{listener port}/{service name}' --statsSrc STATSPACK
         or
          ./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port} --databaseService {service name} --statsSrc STATSPACK


        If Statspack has less than 30 days of data, limit collection to the last 7 days using the paramter --statsWindow:

          ./collect-data.sh --connectionStr 'MyUser/MyPassword@//dbhost.company.com:1521/MyDbName.company.com' --statsSrc STATSPACK --statsWindow 7
         or
          ./collect-data.sh --collectionUserName MyUser --collectionUserPass MyPassword --hostName dbhost.company.com --port 1521 --databaseService MyDbName.company.com --statsSrc STATSPACK --statsWindow 7


        Collections can be run as SYS if needed by setting ORACLE_SID and running on the database host:

          ./collect-data.sh --connectionStr '/ as sysdba' --statsSrc AWR

         or to avoid using the licensed Oracle Tuning and Diagnostics pack data:

          ./collect-data.sh  --connectionStr '/ as sysdba' --statsSrc STATSPACK


        Notes:
            1) Google Database Migration Assessment Data Extractor extracts data for the entire database. In multitenant
               CDB databases, you must connect to the container database.  Running this from within a
               pluggable database will not collect the proper data.

4. Automation
-------------
    If you wish to automate setup and collection from multiple databases, edit the file dma_db_list.csv with connection information and options for each database, one entry per line.
    The file header describes the file format and provides examples.

    Verify the congfiguration file is valid and the sysdba connection information is correct by executing the precheck script with the --verifyUser N option.
      ./dma_precheck.sh --configFile dma_db_list.csv --verifyUser N

    Address any errors reported before continuing.

    If you are creating a new database user or modifying an existing user for DMA collection, execute the dma_make_user.sh script to create or modify the user(s) specified in the configuration file.
      ./dma_make_user.sh --configFile dma_db_list.csv

    If any errors are encountered, address the issue before continuing to the next step.  The dma_make_user.sh script can be run multiple times if needed.  

    Verify the user connection and privilege information by re-running the dma_precheck.sh script without the --verifyUser parameter.  This will verify the user can connect.
      ./dma_precheck.sh --configFile dma_db_list.csv 

    Address any errors reported before continuing.

    Execute automated DMA collection by running the dma_batch_run.sh script.  It can execute collections in parallel via the --maxParallel parameter.  Set this to 1 to disable parallel collection.
    The default is 4.  Note that this controls the number of DMA collections running at one time, not the parallelism of the queries in the database.  Each running collection consumes some disk space 
    for temporary files as the data is extracted.  Very high settings for --maxParallel may consume a lot of space.  The example below shows a limit of two collections running at once.

      ./dma_batch_run.sh --configFile dma_db_list.csv --maxParallel 2

    Collections run via dma_batch_run.sh will automatically create log files for each collection, as the terminal will intermingle the output of all threads.
    

5. Results
----------

    An archive of the extracted results will be created in the directory collector/output.
    The full path and file name will be displayed on completion.


6. License
------------

Copyright 2024 Google LLC

Licensed under the Apache License, Version 2.0 (the "License").
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
