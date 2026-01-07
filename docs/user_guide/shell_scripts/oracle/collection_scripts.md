# Gather workload metadata

The workload collection supports Oracle 10gR1 and newer. Older versions of Oracle are not currently supported.

## System environment

The collection script is designed to run in a Unix or Unix-like environment. It can be run on Windows within either Windows subsystem for Linux or Cygwin.
It depends on the following to be available on the machine from which it is run:

```shell
bash shell
awk
cat
cut
dirname
grep
iconv
locale
md5sum
mkdir
printf
sed
sqlplus
tar
tr
uname
which
xargs
zip or gzip
```

## Execute collection script

Download the latest collection scripts [here](https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-oracle.zip).

```shell
mkdir ./dbma_collector && cd dbma_collector
wget https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-oracle.zip
unzip db-migration-assessment-collection-scripts-oracle.zip
```

- Execute this from a system that can access your database via sqlplus
- Execute from a user with DBA privileges or optionally use the provided creation script

If the extract will be run by a user that does not have SYSDBA privilege, connect to the database
as a user with SYSDBA privileges and create the user if needed. If this is a multi-tenant database,
create the user as a common user in the root container. The Dma_collector does not currently support
running in individual pluggable databases.

For non-CDB databases:

```shell
sqlplus "sys/password@//hostname:port/dbservicename as sysdba"
SQL> create user DMA_COLLECTOR identified by password;
SQL> grant connect, create session to DMA_COLLECTOR;
```

For multitenant databases:

```shell
sqlplus "sys/password@//hostname:port/dbservicename as sysdba"
SQL> create user C##DMA_COLLECTOR identified by password;
SQL> grant connect, create session to C##DMA_COLLECTOR;
```

Navigate to the sql/setup directory and execute grants_wrapper.sql as a user with SYSDBA privileges.
You will be prompted for the name of a database user
(Note that input is case-sensitive and must match the username created above) to be granted
privileges on the objects required for data collection.
You will also be prompted whether or not to allow access to the AWR data.
Access will be granted to Statspack tables if they are present.

For non-CDB databases:

```shell
SQL> @grants_wrapper.sql
SQL> Please enter the DB Local Username(Or CDB Username) to receive all required grants: DMA_COLLECTOR
SQL> Please enter Y or N to allow or disallow use of the Tuning and Diagnostic Pack (AWR) data (Y) Y
```

For multitenant databases:

```shell
SQL> @grants_wrapper.sql
SQL> Please enter the DB Local Username(Or CDB Username) to receive all required grants: C##DMA_COLLECTOR
SQL> Please enter Y or N to allow or disallow use of the Tuning and Diagnostic Pack (AWR) data (Y) Y
```

The grant_wrapper script will grant privileges required and will output a list of what has been granted.

Launch the collection script: (Note that the parameter names have changed from earlier versions of the collector)

- NOTES:
    - If this is an Oracle RAC and/or PDB environment you just need to run it once per database. No need to run in each PDB or in each Oracle RAC instance.
    - If you are licensed for the Oracle Diagnostic pack, specify AWR for the --statsSrc parameter.
    - If you are NOT licensed for the Oracle Diagnostics pack, specify STATSPACK for the --statsSrc parameter.
    - If you do not want to collect performance data, specife NONE for the --statsSrc parameter. This will block the ability to provide sizing and pricing estimates.

    - Parameters

```
 Connection definition must one of:
    {
       --connectionStr       Oracle EasyConnect string formatted as {user}/{password}@//{db host}:{listener port}/{service name}
     or
       --hostName            Database server hostname
       --port                Listener port
       --databaseService     Database service name
       --collectionUserName  Database username
       --collectionUserPass  Database password
    }
 Performance statistics source
     --statsSrc              Required. Must be one of AWR, STATSPACK, NONE.
                             When using STATSPACK, see note about --statsWindow parameter below.
                             When using AWR, ensure you are licensed for the Oracle Diagnostics Pack.
 Performance statistics window
     --statsWindow           Optional. Number of days of performance stats to collect.  Must be one of 7, 30.  Default is 30.
                             NOTE: IF STATSPACK HAS LESS THAN 30 DAYS OF COLLECTION DATA, SET THIS PARAMETER TO 7 TO LIMIT TO 1 WEEK OF COLLECTION.
                             IF STATSPACK HAS BEEN ACTIVATED SPECIFICALLY FOR DMA COLLECTION, ENSURE THERE ARE AT LEAST 8
                             CALENDAR DAYS OF COLLECTION BEFORE RUNNING THE DMA COLLECTOR.
 Customer-supplied unique identifier
     --manualUniqueId        Optional. Descriptive unique identifier for the database being collected.  
                             Do not use the same value for multiple databases.
                             Use no spaces or special characters.
                             Ex: SalesDev, InventoryQA, etc.


 NOTE: If using an Oracle auto-login wallet, specify the tns alias as the connection string:
  Ex:
    ./collect-data.sh --connectionStr /@mywalletalias --statsSrc AWR
```

To use the licensed Oracle Diagnostic pack AWR/ASH data:

```shell
./collect-data.sh --connectionStr {user}/{password}@//{db host}:{listener port}/{service name} --statsSrc AWR
or
./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port} --databaseService {service name} --statsSrc AWR

ex:

./collect-data.sh --connectionStr MyUser/MyPassword@//dbhost.company.com:1521/MyDbName.company.com --statsSrc AWR
or
./collect-data.sh --collectionUserName MyUser --collectionUserPass MyPassword --hostName dbhost.company.com --port 1521 --databaseService MyDbName.company.com --statsSrc AWR
```

OR
To use performance data from STATSPACK collection:

```shell
./collect-data.sh --connectionStr {user}/{password}@//{db hosti}:{listener port}/{service name} --statsSrc STATSPACK
or
./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port} --databaseService {service name} --statsSrc STATSPACK

ex:

./collect-data.sh --connectionStr MyUser/MyPassword@//dbhost.company.com:1521/MyDbName.company.com --statsSrc STATSPACK
or
./collect-data.sh --collectionUserName MyUser --collectionUserPass MyPassword --hostName dbhost.company.com --port 1521 --databaseService MyDbName.company.com --statsSrc STATSPACK


If Statspack has less than 30 days of data, limit collection to the last 7 days using the parameter --statsWindow:

./collect-data.sh --connectionStr MyUser/MyPassword@//dbhost.company.com:1521/MyDbName.company.com --statsSrc STATSPACK --statsWindow 7
or
./collect-data.sh --collectionUserName MyUser --collectionUserPass MyPassword --hostName dbhost.company.com --port 1521 --databaseService MyDbName.company.com --statsSrc STATSPACK --statsWindow 7
```

Collections can be run as SYS if needed by setting ORACLE_SID and running on the database host:

To use the licensed Oracle Diagnostic pack AWR/ASH data:

```shell
./collect-data.sh --connectionStr '/ as sysdba' --statsSrc AWR
```

OR
To use performance data from STATSPACK collection:

```shell
./collect-data.sh  --connectionStr '/ as sysdba' --statsSrc STATSPACK
```

# Automation
User creation and data collection across many databases can be automated.

    If you wish to automate setup and collection from multiple databases, edit the file dma_db_list.csv with connection information and options for each database, one entry per line.
    The file header describes the file format and provides examples.

## Automation prechecks and user creation
    Verify the configuration file is valid and the sysdba connection information is correct by executing the precheck script with the --verifyUser N option.
      ./dma_precheck.sh --configFile dma_db_list.csv --verifyUser N

    Address any errors reported before continuing.

    If you are creating a new database user or modifying an existing user for DMA collection, execute the dma_make_user.sh script to create or modify the user(s) specified in the configuration file.
      ./dma_make_user.sh --configFile dma_db_list.csv

    If any errors are encountered, address the issue before continuing to the next step.  The dma_make_user.sh script can be run multiple times if needed.

    Verify the user connection and privilege information by re-running the dma_precheck.sh script without the --verifyUser parameter.  This will verify the user can connect.
      ./dma_precheck.sh --configFile dma_db_list.csv

    Address any errors reported before continuing.

## Automated data collection
    Execute automated DMA collection by running the dma_batch_run.sh script.  It can execute collections in parallel via the --maxParallel parameter.  Set this to 1 to disable parallel collection.
    The default is 4.  Note that this controls the number of DMA collections running at one time, not the parallelism of the queries in the database.  Each running collection consumes some disk space
    for temporary files as the data is extracted.  Very high settings for --maxParallel may consume a lot of space.  The example below shows a limit of two collections running at once.

      ./dma_batch_run.sh --configFile dma_db_list.csv --maxParallel 2

    Collections run via dma_batch_run.sh will automatically create log files for each collection, as the terminal will intermingle the output of all threads.



## Upload Collections

Upon completion, the tool will automatically create an archive of the extracted metrics that can be uploaded into the assessment tool.  Do not modify the file names or contents.
