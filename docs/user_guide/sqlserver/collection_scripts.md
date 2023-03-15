# Gather workload metadata

The workload collection supports Microsoft SQL Server 2019 and newer.  Older versions of Microsoft SQL Server are not currently supported.

## Sytem environment

The collection script depends on the following to be available on the machine from which it is run:
```command prompt
	powershell
	sqlcmd
```

## Download the latest collection scripts

Download the latest collection scripts [here](https://github.com/GoogleCloudPlatform/oracle-database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-sqlserver.zip).

```shell
mkdir ./dbma_collector && cd dbma_collector
wget https://github.com/GoogleCloudPlatform/oracle-database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-oracle.zip  
unzip db-migration-assessment-collection-scripts-oracle.zip
```

- Currently this script needs to be executed from the system where the database is running
- Execute from a user with DBA privileges or optionally use the provided user creation script

If the extract will be run by a user that does not have DBA (SA) privilege, connect to the database as a user with DBA (SA) privileges and create the user if needed.  The "DMA Collector" currenlty connects to the master database does not currently support running in individual SQL Server databases.

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

If you a different username and password needs to be used for the collection you can either invoke the `InstanceReview.ps1` script directly, passing in the following parameters:

```shell
	InstanceReview.ps1 -user [username] -pass [password]
```

Or modify the the `RunAssessment.bat` file directly and add the parameters to the execution.

## Execute the collection script

To invoke the collection script using `RunAssessment.bat`:
```shell
.\RunAssessment.bat
```
OR
To invoke the powershell script directly using the default user and password:
```shell
.\InstanceReview.ps1
```
OR
To invoke the powershell script directly using a custom user and password:
```shell
.\InstanceReview.ps1 -user [username] -pass [password]
```

## Upload Collections

Upon completion, the tool will automatically create an archive of the extracted metrics that can be uploaded into the assessment tool.
