# Gather workload metadata

The workload collection supports Oracle 10gR1 and newer.  Older versions of Oracle are not currently supported.

## System environment

The collection script is designed to run in a Unix or Unix-like environment.  It can be run on Windows within either Windows subsystem for Linux or Cygwin.
It depends on the following to be available on the machine from which it is run:

```shell
bash shell
cat
cut
dirname
grep
locale
mkdir
sed
sqlplus
tar
tr
which
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
as a user with SYSDBA privileges and create the user if needed.  If this is a multi-tenant database,
create the user as a common user in the root container. The Dma_collector does not currently support
running in individual pluggable databases.


```shell
sqlplus "sys/password@//hostname:port/dbservicename"
SQL> create user DMA_COLLECTOR identified by password;
SQL> grant connect, create session to DMA_COLLECTOR;
```

Execute grants_wrapper.sql.  You will be prompted for the name of a database user
(Note that input is case-sensitive and must match the username created above) to be granted
privileges on the objects required for data collection.
You will also be prompted whether or not to allow access to the AWR data.

```shell
SQL> @grants_wrapper.sql
SQL> Please enter the DB Local Username(Or CDB Username) to receive all required grants: DMA_COLLECTOR
SQL> Please enter Y or N to allow or disallow use of the Tuning and Diagnostic Pack (AWR) data (Y) Y
```

The grant_wrapper script will grant privileges required and will output a list of what has been granted.

Launch the collection script:

- Pass connect string as input to this script and either UseDiagnostics or NoDiagnostics to match the permissions granted. (see below for example)
- NOTE: If this is an Oracle RAC and/or PDB environment you just need to run it once per database. No need to run in each PDB or in each Oracle RAC instance.
  - If you are licensed for the Oracle Tuning and Diagnostics packs, pass the parameter UseDiagnostics to use the AWR data.
  - If you are NOT licensed for the  Oracle Tuning and Diagnostics packs, pass the parameter NoDiagnostics to exclude the AWR data.  The script will attempt to use STATSPACK data if available.

To use the licensed Oracle Tuning and Diagnostics pack data:

```shell
./collect-data.sh {user}/{password}@//{db host/scan address}/{service name} UseDiagnostics
```

OR
To avoid using the licensed Oracle Tuning and Diagnostics pack data:

```shell
./collect-data.sh {user}/{password}@//{db host/scan address}/{service name} NoDiagnostics
```

Collections can be run as SYS if needed by setting ORACLE_SID and running on the database host:

```shell
./collect-data.sh '/ as sysdba' UseDiagnostics
```

OR
To avoid using the licensed Oracle Tuning and Diagnostics pack data:

```shell
./collect-data.sh '/ as sysdba' NoDiagnostics
```


## Upload Collections

Upon completion, the tool will automatically create an archive of the extracted metrics that can be uploaded into the assessment tool.
