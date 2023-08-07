# Google Cloud Database Migration Assessment for Microsoft SQL Server

Instructions on how to prepare and run Google Database Migration Assessment Data Extractor for Microsoft SQL Server to extract the data required for analysis by the Database Migration Assessment tool.

These scripts have been tested with the following platforms:

SQL Server Versions:

- SQL Server 2008R2 SP2 through SQL Server 2022
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

This utility must be run as a database user with privileges to SELECT from certain data dictionary views. The scripts "createUserForAssessmentWithSQLAuth.bat" and "createUserForAssessmentWithWindowsAuth.bat" are supplied to create the required user and privileges. Instructions for executing it are below. Alternatively, you may use a user that already has the required privileges.

---

## System Requirements

The collection script depends on the following executables to be available on the machine from which it is run. The script is also expected to be run from a Windows machine in "Administrator Mode":

```shell
command prompt
powershell (version 5 or greater)
sqlcmd (ensure that it is in your $PATH)
```

---

## Preparation

In order to begin running the Database Migration Assessment Collection process, download the collector script from [here](https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-sqlserver.zip) onto the host to be collected and follow the below instructions:

<br/>

    - Alternative download instructions:
        mkdir ./dbma_collector && cd dbma_collector
        wget https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-sqlserver.zip

    - Unzip the install archive:
        unzip db-migration-assessment-collection-scripts-sqlserver.zip

    - As of the current release, the collection scripts require a user with the SYSADMIN privilege.  An existing user may be used or one can be created using the scripts as shown below:

        If an existing user with SYSADMIN privileges wil not be used, from a command prompt, execute either of the following scripts depending on what type of authentication you currently use for your SYSADMIN user.

        In this example the collection user will use SQL Authentication:
            - createUserForAssessmentWithSQLAuth.bat
                The following parameters can be specified:
                    -serverName  ** Required
                    -port  ** Optional (Defaults to 1433)
                    -serverUserName  ** Required
                    -serverUserPass  ** Required
                    -collectionUserName  ** Required
                    -collectionUserPass  ** Required

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
                    -collectionUserPass  ** Required

            For a Named Instance:
                createUserForAssessmentWithWindowsAuth.bat -serverName [servername\instanceName] -port [port number] -collectionUserName [collection user name] -collectionUserPass [collection user password]

            For a Default Instance:
                createUserForAssessmentWithWindowsAuth.bat -serverName [servername] -port [port number] -collectionUserName [collection user name] -collectionUserPass [collection user password]

---

## Execution

#### Perfmon Requirements (Optional)

- If you have your own perfmon counters capturing the following statistics or run on a SQL Server Product such as Amazon RDS or Google CloudSQL for SQL Server, skip to step b, otherwise proceed to step a.
  \*\* The Perfmon data collection process is optional and can be safely skipped. However, there will be no right sizing information in the assessment report.
  <br/>

          \Memory\Available MBytes
          \PhysicalDisk(_Total)\Avg. Disk Bytes/Read
          \PhysicalDisk(_Total)\Avg. Disk Bytes/Write
          \PhysicalDisk(_Total)\Avg. Disk sec/Read
          \PhysicalDisk(_Total)\Avg. Disk sec/Write
          \PhysicalDisk(_Total)\Disk Reads/sec
          \PhysicalDisk(_Total)\Disk Writes/sec
          \Processor(_Total)\% Idle Time
          \Processor(_Total)\% Processor Time
          \Processor Information(_Total)\Processor Frequency
          \System\Processor Queue Length
          \SQLServer:Buffer Manager\Buffer cache hit ratio
          \SQLServer:Buffer Manager\Checkpoint pages/sec
          \SQLServer:Buffer Manager\Free list stalls/sec
          \SQLServer:Buffer Manager\Page life expectancy
          \SQLServer:Buffer Manager\Page lookups/sec
          \SQLServer:Buffer Manager\Page reads/sec
          \SQLServer:Buffer Manager\Page writes/sec
          \SQLServer:General Statistics\User Connections
          \SQLServer:Memory Manager\Memory Grants Pending
          \SQLServer:Memory Manager\Target Server Memory (KB)
          \SQLServer:Memory Manager\Total Server Memory (KB)
          \SQLServer:SQL Statistics\Batch Requests/sec

      <br/>

- From a command prompt session in "Administrator Mode" on the server you would like to collect data on, execute the following command:

* ManageSqlServerPerfmonDatset.bat
  The following parameters can be specified:
  - -operation \*\* Required (create, start, stop, delete, collect, createemptyfile, help)
  - -instanceType \*\* Required (default, managed)
  - -mssqlInstanceName \*\* Required if instanceType is "managed" (should be the instance name without the server name)

To create and start the perfmon collection:

        For a default instance:
            ManageSqlServerPerfmonDatset.bat -operation create -instanceType default

        For a named instance:
            ManageSqlServerPerfmonDatset.bat -operation create -instanceType managed -mssqlInstanceName [instance name]

The script will create a permon data set that will collect the above metrics at a 1 minute interval for 8 days. The dataset will automatically stop after 8 days of collection. To get the most accurate statistics, it would be good to have this collection run over the busiest time for the server.

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

To Execute the Collection:

      For a default instance (all databases):
        runAssessment.bat -serverName [servername] -port [port number] -collectionUserName [collection user name] -collectionUserPass [collection user password]

        Example (default port): runAssessment.bat -serverName MS-SERVER1 -collectionUserName sa -collectionUserPass password123
        Example (custom port): runAssessment.bat -serverName MS-SERVER1 -port 1435 -collectionUserName sa -collectionUserPass password123

      For a default instance (single database):
        runAssessment.bat -serverName [servername] -port [port number] -database [single database name] -collectionUserName [collection user name] -collectionUserPass [collection user password]

        Example (default port): runAssessment.bat -serverName MS-SERVER1 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123
        Example (custom port): runAssessment.bat -serverName MS-SERVER1 -port 1435 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123

      For a named instance (all databases):
        runAssessment.bat -serverName [servername\instanceName] -port [port number] -collectionUserName [collection user name] -collectionUserPass [collection user password]

        Example (default port): runAssessment.bat -serverName MS-SERVER1/SQL2019 -collectionUserName sa -collectionUserPass password123
        Example (custom port): runAssessment.bat -serverName MS-SERVER1 -port 1435 -collectionUserName sa -collectionUserPass password123

      For a named instance (single database):
        runAssessment.bat -serverName [servername\instanceName] -port [port number] -database [single database name] -collectionUserName [collection user name] -collectionUserPass [collection user password]

        Example (default port): runAssessment.bat -serverName MS-SERVER1/SQL2019 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123
        Example (custom port): runAssessment.bat -serverName MS-SERVER1 -port 1437 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123

      For Azure SQL Database (Ignore Perfmon Collection):
        runAssessment.bat -serverName [servername] -port [port number] -database [database name] -collectionUserName [collection user name] -collectionUserPass [collection user password] -ignorePerfmon true

        Example (default port): runAssessment.bat -serverName MS-SERVER1 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon true
        Example (custom port): runAssessment.bat -serverName MS-SERVER1 -port 1435 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon true
        Example (default port / all databases): runAssessment.bat -serverName MS-SERVER1 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon true
        Example (custom port / all databases): runAssessment.bat -serverName MS-SERVER1 -port 1435 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon true



        Notes:
          1. Google Database Migration Assessment Data Extractor extracts data for all user databases present in the instance
          2. Collection scripts should be executed from an "Administrator Mode" command prompt
          3. When using a port to connect only provide the local host name

---

## Return Results

- An archive of the extracted results will be created in the directory collector/output.
- The full path and file name will be displayed on completion.
- Return the listed file to Google for processing

!!! IMPORTANT Do not modify the name or the contents of the zip file without consultation from Google.

## License

Copyright 2023 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
