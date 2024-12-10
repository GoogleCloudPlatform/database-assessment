# Google Cloud Database Migration Assessment for Microsoft SQL Server

Instructions on how to prepare and run Google Database Migration Assessment Data Extractor for Microsoft SQL Server to extract the data required for analysis by the Database Migration Assessment tool.

These scripts have been tested with the following platforms:

SQL Server Versions:

- SQL Server 2008 (SP4-GDR) (KB5020863) - 10.0.6814.4 (X64) through SQL Server 2022
- AZURE SQL Database

Operating System Versions:

- Windows Server 2012 through Windows Server 2022 (Requires PowerShell Version 5 or Greater)

---

## Introduction

This utility extracts metadata about the tables, partitions and SQL workload in a database into CSV files. It also leverages perfmon data that must have a perfmon counter started before the final data collection. These CSV files are then used by Database Migration Assessment internally to analyze the data with Google Database Migration Assessment.

---

## License Requirements

!!! IMPORTANT Google Database Migration Assessment does not require any additional licensing with regards to Microsoft SQL Server.

---

## Database Privileges

This utility must be run as a database user with privileges to SELECT from certain data dictionary views. The scripts "createUserForAssessmentWithSQLAuth.bat" and "createUserForAssessmentWithWindowsAuth.bat" are supplied to create the required user and privileges. Instructions for executing it are below. Alternatively, you may use a user that already has following privileges:

In the master database:

```sql
  GRANT VIEW SERVER STATE TO [username];
  GRANT SELECT ALL USER SECURABLES TO [username];
  GRANT VIEW ANY DATABASE TO [username];
  GRANT VIEW ANY DEFINITION TO [username];
  GRANT VIEW SERVER STATE TO [username];
  GRANT VIEW DATABASE STATE TO [username];
```

In addition the user must also be mapped to all user databases, tempdb and master databases along with the following grant:

```sql
  use [user database name];
  CREATE USER [username] FOR LOGIN [username];
  GRANT VIEW DATABASE STATE TO [username];
```

---

## System Requirements

The collection script depends on the following executables to be available on the machine from which it is run. The script is also expected to be run from a Windows machine in "Administrator Mode":

```shell
command prompt
powershell (version 5 or greater)
sqlcmd (version 11.0.7512.11 or greater)
```

If needed sqlcmd can be downloaded from [here](https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility?view=sql-server-ver16&tabs=odbc%2Cwindows#download-and-install-sqlcmd)

!!! note

    Ensure that the `ODBC` version of `sqlcmd` is used
    Ensure that `sqlcmd` is also in your `$PATH` variable

---

## Preparation

In order to begin running the Database Migration Assessment Collection process, download the collector script from [here](https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-sqlserver.zip) onto the host to be collected and follow the below instructions:

<br/>

    - Alternative download instructions:
        mkdir ./dbma_collector && cd dbma_collector
        wget https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-sqlserver.zip

    - Unzip the install archive:
        unzip db-migration-assessment-collection-scripts-sqlserver.zip

    - An existing user may be used or one can be created using the scripts as shown below.  SYSADMIN is not required although a user with that privilege may be used:

        If an existing user with SYSADMIN privileges wil not be used, from a command prompt, execute either of the following scripts depending on what type of authentication you currently use for your SYSADMIN user.

        In this example the collection user will use SQL Authentication:
            - createUserForAssessmentWithSQLAuth.bat
                The following parameters can be specified:
                    -serverName  ** Required
                    -port  ** Optional (Defaults to 1433)
                    -serverUserName  ** Required
                    -serverUserPass  ** Required
                    -collectionUserName  ** Required
                    -collectionUserPass  ** Optional (If not provided will be prompted)

            For a Named Instance:
                createUserForAssessmentWithSQLAuth.bat -serverName [servername\instanceName] -port [port number] -serverUserName [existing privileged user] -serverUserPass [privileged user password] -collectionUserName [collection user name] -collectionUserPass [collection user password]

            For a Default Instance:
                createUserForAssessmentWithSQLAuth.bat -serverName [servername] -port [port number] -collectionUserName [collection user name] -collectionUserPass [collection user password]

        In this example, the created user will use Windows Authentication:
            - createUserForAssessmentWithWindowsAuth.bat
                The following parameters can be specified:
                    -serverName  ** Required
                    -port  ** Optional (Defaults to 1433)
                    -collectionUserName  ** Required
                    -collectionUserPass  ** Optional (If not provided will be prompted)

            For a Named Instance:
                createUserForAssessmentWithWindowsAuth.bat -serverName [servername\instanceName] -port [port number] -collectionUserName [collection user name] -collectionUserPass [collection user password]

            For a Default Instance:
                createUserForAssessmentWithWindowsAuth.bat -serverName [servername] -port [port number] -collectionUserName [collection user name] -collectionUserPass [collection user password]

---

## Execution

#### Perfmon Requirements (Optional)

- NOTE: Executing Perfmon is OPTIONAL. If not executed the tool will evaluate complexity of migration, but not rightsizing requirements.
- NOTE: The standard perfmon collector collects every 10 minutes for 8 days.

- If you have your own perfmon counters capturing the following statistics or run on a SQL Server Product such as Amazon RDS or Google CloudSQL for SQL Server, skip to step b, otherwise proceed to step a.
  \*\* The Perfmon data collection process is optional and can be safely skipped. However, there will be no right sizing information in the assessment report.
  <br/>

            \Memory\Available MBytes
                total amount of available memory on the system
            \PhysicalDisk(_Total)\Avg. Disk Bytes/Read
                shows the average size of read operations on a volume in bytes
            \PhysicalDisk(_Total)\Avg. Disk Bytes/Write
                shows the average size of write operations on a volume in bytes
            \PhysicalDisk(_Total)\Avg. Disk sec/Read
                displays the average time in seconds it takes to read data from a disk
            \PhysicalDisk(_Total)\Avg. Disk sec/Write
                displays the average time in seconds it takes to write data to a disk
            \PhysicalDisk(_Total)\Disk Reads/sec
                displays the read IOPS from a file per second (if file is in file cache this counter is not incremented)
            \PhysicalDisk(_Total)\Disk Writes/sec
                displays the write IOPS to a file per second (if file is in file cache this counter is not incremented)
            \Processor(_Total)\% Idle Time
                the percentage of time a processor spends on idle threads
            \Processor(_Total)\% Processor Time
                displays the percentage of time a processor spends executing non-idle threads
            \Processor Information(_Total)\Processor Frequency
                processor frequency
            \System\Processor Queue Length
                number of threads that are ready to execute but waiting for a core to become available
            \SQLServer:Buffer Manager\Buffer cache hit ratio
                this ratio is a measure of the percentage of pages that were found in memory (SQL buffer pool) without having to be read from disk.
            \SQLServer:Buffer Manager\Checkpoint pages/sec
                the number of dirty pages that are moved from the SQL buffer pool to disk during a checkpoint.
            \SQLServer:Buffer Manager\Free list stalls/sec
                how many requests per second are waiting for a free page (values above 2 means server needs more memory)
            \SQLServer:Buffer Manager\Page life expectancy
                indicates the memory pressure in allocated memory to the SQL Server instance
            \SQLServer:Buffer Manager\Page lookups/sec
                number of requests to find a page in the buffer pool
            \SQLServer:Buffer Manager\Page reads/sec
                rate at which the disk is read to resolve page faults (pages read into memory)
            \SQLServer:Buffer Manager\Page writes/sec
                rate at which page data is written to the disk to open up space in physical memory
            \SQLServer:General Statistics\User Connections
                number of current connections to SQL Server.
            \SQLServer:Memory Manager\Memory Grants Pending
                total number of SQL Server processes that are waiting for workspace memory to be granted (Should nearly always be zero)
            \SQLServer:Memory Manager\Target Server Memory (KB)
                the amount of memory that SQL Server can potentially consume
            \SQLServer:Memory Manager\Total Server Memory (KB)
                the amount of memory the server has committed using the memory manager
            \SQLServer:SQL Statistics\Batch Requests/sec
                number of T-SQL commands that are being received by the server per second
            \NUMA Node Memory(_Total)\Total MBytes
                represents the total amount of physical memory associated with a NUMA node in megabytes
            \NUMA Node Memory(_Total)\Available MBytes
                represents the free amount of physical memory associated with a NUMA node in megabytes
		    \Process(_Total)\IO Read Operations/sec
                shows the rate at which a process issues read I/O operations. This counter includes all I/O activity generated by the process, including file, network, and device I/O's
            \Process(_Total)\IO Write Operations/sec
                shows the rate at which a process issues write I/O operations. This counter includes all I/O activity generated by the process, including file, network, and device I/O's
            \Process(_Total)\IO Read Bytes/sec
                shows the rate at which a process reads bytes in I/O operations. This counter includes all I/O activity generated by the process, such as file, network, and device I/O.
            \Process(_Total)\IO Write Bytes/sec
                shows the rate at which a process writes bytes in I/O operations. This counter includes all I/O activity generated by the process, such as file, network, and device I/O.

      <br/>

- From a command prompt session in "Administrator Mode" on the server you would like to collect data on, execute the following command:

* manageSQLServerPerfmonDataset.bat
  The following parameters can be specified:
  - -operation \*\* Required (create, start, stop, delete, collect, createemptyfile, help)
  - -instanceType \*\* Required (default, named)
  - -namedInstanceName \*\* Required if instanceType is "named" (should be the instance name without the server name)
  - -sampleDuration \*\* The number of intervals that perfmon sample will run defaults to 1152 (10 minute samples for 8 days)
  - -sampleInterval \*\* The interval that perfmon sample will run defaults to 600 (every 10 minutes)

To create and start the perfmon collection:

        For a default instance:
            manageSQLServerPerfmonDataset.bat -operation create -instanceType default -sampleDuration [number of intervals to sample] -sampleInterval [frequency of sample intervals in seconds]

        For a named instance:
            manageSQLServerPerfmonDataset.bat -operation create -instanceType named -namedInstanceName [instance name] -sampleDuration [number of intervals to sample] -sampleInterval [frequency of sample intervals in seconds]

The script will create a permon data set that will collect the above metrics at a 10 minute intervals for 8 days. The dataset will automatically stop after 8 days of collection. To get the most accurate statistics, it would be good to have this collection run over the busiest time for the server.

<br/>

#### Perform Collection

- When the perfmon dataset completes or if you would like to execute the collection sooner, execute the following command from a command prompt session in "Administrator Mode" on the server you would like to collect data on and return the subsequent .zip file to Google.
- The collection can also be run for all user databases or a single user database. See the below examples for each scenario
  <br/>

* runAssessment.bat
  The following parameters can be specified:
  - -serverName \*\*Required
  - -port \*\*Optional (Defaults to 1433)
  - -database \*\*Optional (Defaults to all user databases)
  - -collectionUserName \*\*Required
  - -collectionUserPass \*\*Required
  - -ignorePerfmon \*\*Optional (Defaults to "false" / Set to "true" to ignore perfmon collection)
  - -manualUniqueId \*\*Optional (Defaults to "NA" - Gives the ability the user to tag their collection with a unique name)
  - -collectVMSpecs \*\*Optional switch. See [below](#collectvmspecs).
  - -outputDirectory  \*\*Optional (write the final zip file to another location - must be escaped properly if spaces are in the directory name)

To Execute the Collection:

      For a default instance (all databases):
        runAssessment.bat -serverName [servername] -port [port number] -collectionUserName [collection user name] -collectionUserPass [collection user password] -manualUniqueId [string]

        Example (default port): runAssessment.bat -serverName MS-SERVER1 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string]
        Example (custom port): runAssessment.bat -serverName MS-SERVER1 -port 1435 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string]

      For a default instance (single database):
        runAssessment.bat -serverName [servername] -port [port number] -database [single database name] -collectionUserName [collection user name] -collectionUserPass [collection user password] -manualUniqueId [string]

        Example (default port): runAssessment.bat -serverName MS-SERVER1 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string]
        Example (custom port): runAssessment.bat -serverName MS-SERVER1 -port 1435 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string]

      For a named instance (all databases):
        runAssessment.bat -serverName [servername\instanceName] -port [port number] -collectionUserName [collection user name] -collectionUserPass [collection user password] -manualUniqueId [string]

        Example (default port): runAssessment.bat -serverName MS-SERVER1/SQL2019 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string]
        Example (custom port): runAssessment.bat -serverName MS-SERVER1 -port 1435 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string]

      For a named instance (single database):
        runAssessment.bat -serverName [servername\instanceName] -port [port number] -database [single database name] -collectionUserName [collection user name] -collectionUserPass [collection user password] -manualUniqueId [string]

        Example (default port): runAssessment.bat -serverName MS-SERVER1/SQL2019 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string]
        Example (custom port): runAssessment.bat -serverName MS-SERVER1 -port 1437 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string]

      For Azure SQL Database (Ignore Perfmon Collection):
        runAssessment.bat -serverName [servername] -port [port number] -database [database name] -collectionUserName [collection user name] -collectionUserPass [collection user password] -ignorePerfmon true -manualUniqueId [string]

        Example (default port): runAssessment.bat -serverName MS-SERVER1 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon true -manualUniqueId [string]
        Example (custom port): runAssessment.bat -serverName MS-SERVER1 -port 1435 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon true -manualUniqueId [string]
        Example (default port / all databases): runAssessment.bat -serverName MS-SERVER1 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon true -manualUniqueId [string]
        Example (custom port / all databases): runAssessment.bat -serverName MS-SERVER1 -port 1435 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon true -manualUniqueId [string]



        Notes:
          1. Google Database Migration Assessment Data Extractor extracts data for all user databases present in the instance
          2. Collection scripts should be executed from an "Administrator Mode" command prompt
          3. When using a port to connect only provide the local host name
          4. The manualUniqueId can be used to give the collection a unique identifier specified by the customer

##### CollectVMSpecs:

To provide rightsizing information the script attempts to connect to the host VM using the current users credentials and collect hardware specs (number of CPUs/amount of memory).

If the current user does not have sufficient permissions, it will skip this step. To manually input the correct credentials instead when this occurs, specify the `-collectVMSpecs` switch.

This is recommended if you plan to upload the results to the Migration Center.

        Example: runAssessment.bat -serverName MS-SERVER1 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string] -collectVMSpecs

---

## Return Results

- An archive of the extracted results will be created in the directory collector/output.
- The full path and file name will be displayed on completion.
- Return the listed file to Google for processing

!!! IMPORTANT Do not modify the name or the contents of the zip file without consultation from Google.

## License

Copyright 2024 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
