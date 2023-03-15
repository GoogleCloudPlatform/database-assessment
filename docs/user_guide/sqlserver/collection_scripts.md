# Gather workload metadata

The workload collection supports Microsoft SQL Server 2016 and newer.  Older versions of Microsoft SQL Server are not currently supported.

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

If the extract will be run by a user that does not have DBA (SA) privilege, connect to the database as a user with DBA (SA) privileges and create the user if needed.  The "DMA Collector" currently connects to the master database does not currently support running in individual SQL Server databases.

If a user needs to be created, consult the section on user creation.

## Prepare for the collection
Update the `sqlsrv.csv` file to contain the instance name you would like to perform the collection against.  If there are multiple instances on the same host, list them line by line, leaving the header present.  For example an entry for the default instance:

```csv
InstanceName
MS-SERVER1\MSSQLSERVER
```
An entry for a named instance would appear like:
```csv
InstanceName
MS-SERVER1\TESTINSTANCE
```

## Create a Collection User (Optional)
Refer to the [db_user_create](db_user_create.md) page on how to create a collection user and the permisions required if an existing user is to be used.

If a custom username and password needs to be used for the collection you can either invoke the `InstanceReview.ps1` script directly, passing in the following parameters:

```shell
InstanceReview.ps1 -user [username] -pass [password]
```

Or modify the the `RunAssessment.bat` file directly and add the parameters to the execution.

## Execute the collection scripts

### Create the Perfmon Dataset

In order to provide the necessary metrics to the assessment tool, a windows perfmon dataset must be created.  The tool will create a dataset with the required metrics, start the collection and automatically shut down after 8 days.  The collection samples only every 60 seconds to avoid being resource intensive.

To create the perfmon dataset invoke powershell and execute the following script `dma_sqlserver_perfmon_dataset.ps1`.

For a default instance:
```powershell
.\dma_sqlserver_perfmon_dataset.ps1 -create
```
For a named instance:
```powershell
.\dma_sqlserver_perfmon_dataset.ps1 -create -mssqlInstanceName [instance name]
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

Upon completion, the tool will automatically create an archive of the extracted metrics that can be uploaded into the assessment tool.  Deliver the archive to Google for proper analysis.
