# Gather workload metadata

The workload collection supports Microsoft SQL Server 2017 and newer. Older versions of Microsoft SQL Server are not currently supported.

## System environment

The collection script depends on the following to be available on the machine from which it is run:

```shell
command prompt
powershell
sqlcmd
```

## Download the latest collection scripts

Download the latest collection scripts [here](https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-sqlserver.zip).

```shell
mkdir ./dbma_collector && cd dbma_collector
wget https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-sqlserver.zip
unzip db-migration-assessment-collection-scripts-sqlserver.zip
```

- Currently this script needs to be executed from the system where the database is running
- Execute from a user with DBA privileges or optionally use the provided user creation script

If the extract will be run by a user that does not have DBA (SA) privilege, connect to the database as a user with DBA (SA) privileges and create the user if needed. The "DMA Collector" currently connects to the master database does not currently support running in individual SQL Server databases.

If a user needs to be created, consult the section on user creation.

## Prepare for the collection

Identify the instances that are to be collected. This data will be needed to supply the script parameter -serverName. This parameter is usually in the following form:

```text
MS-SERVER1\MSSQLSERVER
10.0.0.1\MSSQLSERVER
```

An entry for a named instance would appear like:

```text
MS-SERVER1\TESTINSTANCE
10.0.0.1\TESTINSTANCE
```

## Create a Collection User (Optional)

Refer to the [db_user_create](db_user_create.md) page on how to create a collection user and the permisions required if an existing user is to be used.

## Execute the collection scripts

### Create the Perfmon Dataset

In order to provide the necessary metrics to the assessment tool, a windows perfmon dataset must be created. The tool will create a dataset with the required metrics, start the collection and automatically shut down after 8 days. The collection samples only every 60 seconds to avoid being resource intensive.

Currently this portion of the script requires invocation on the host where data is being collected.

To create the perfmon dataset invoke powershell and execute the following script `ManageSqlServerPerfmonDataset.bat`.

For a default instance:

```powershell
.\ManageSqlServerPerfmonDataset.bat -operation create
```

For a named instance:

```powershell
.\ManageSqlServerPerfmonDataset.bat -operation create -mssqlInstanceName [instance name]
```

After an adequate amount of perfmon data has been collected, complete the collection by invoking the collection script `RunAssessment.bat`.

If the default username / password provided in the `db_user_create` step is to be used:

```powershell
.\RunAssessment.bat -useDefaultCreds
```

If the default username / password provided in the `db_user_create` step is to be used:

```powershell
.\RunAssessment.bat -username [username] -password [password]
```

If you do not wish to specify the password on the command line, the script will prompt for a password.

## Upload Collections

Upon completion, the tool will automatically create an archive of the extracted metrics that can be uploaded into the assessment tool. Deliver the archive to Google for proper analysis.

### Remove the Perfmon Dataset

When the collection is completed and uploaded, you can remove the dataset by following the below instructions

For a default instance:

```powershell
.\ManageSqlServerPerfmonDataset.bat -operation delete
```

For a named instance:

```powershell
.\ManageSqlServerPerfmonDataset.bat -operation delete -mssqlInstanceName [instance name]
```

### Manually Stopping the Perfmon Dataset

If the perfmon dataset should need to be stopped for any reason it can be stopped by utilizing the below instructions:

For a default instance:

```powershell
.\ManageSqlServerPerfmonDataset.bat -operation delete
```

For a named instance:

```powershell
.\ManageSqlServerPerfmonDataset.bat -operation delete -mssqlInstanceName [instance name]
```
