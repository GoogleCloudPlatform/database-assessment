README
======
Instructions on how to prepare and run Google Database Migration Assessment Data Extractor for Microsoft SQL Server to extract the data required
for analysis by Database Migration Assessment.

These scripts have been tested with the following platforms:
    SQL Server Versions:

        SQL Server 2008 (SP4-GDR) (KB5020863) - 10.0.6814.4 (X64) through SQL Server 2022
        AZURE SQL Database

Operating System Versions:

    Windows Server 2012 through Windows Server 2022 (Requires PowerShell Version 5 or Greater)

1. Background
-------------

    This utility extracts metadata about the tables, partitions and SQL workload in a database into CSV files.  It also leverages perfmon data that must have a perfmon counter started before the final data collection.  These CSV files are then used by Database Migration Assessment internally to analyze the data with Google Database Migration Assessment.

    a) License Requirements
    -----------------------
    !!! IMPORTANT !!! Google Database Migration Assessment does not require any additional licensing with regards to Microsoft SQL Server.

    b) Database Privileges
    ----------------------
    This utility must be run as a database user with privileges to SELECT from certain data dictionary views.
    The scripts "createUserForAssessmentWithSQLAuth.bat" and "createUserForAssessmentWithWindowsAuth.bat" are supplied to create the required user and privileges.  Instructions for executing it are below. Alternatively, you may use a user that already has the required privileges (include privileges in the appendix)

    c) System Requirements
    ----------------------
    The collection script depends on the following executables to be available on the machine from which it is run.  The script is also expected to be run from a Windows machine:
    command shell (in administrator mode)
    powershell (version 5 or greater)
    sqlcmd.exe (version 11.0.7512.11 or greater)

        Note:
        ----------------------
        Ensure that the "ODBC" version of "sqlcmd" is used
        Ensure that "sqlcmd" is also in your "$PATH" variable

2. Preparation
--------------

    a) Unzip the install archive.

    b) As of the current release, the collection scripts require a user with the SYSADMIN privilege.
        An existing user may be used or one can be created using the scripts as shown below:

        In the master database:
            GRANT VIEW SERVER STATE TO [username];
            GRANT SELECT ALL USER SECURABLES TO [username];
            GRANT VIEW ANY DATABASE TO [username];
            GRANT VIEW ANY DEFINITION TO [username];
            GRANT VIEW SERVER STATE TO [username];

            For SQL Server Version 2022 and above the following additional permissions are needed:
                GRANT VIEW SERVER PERFORMANCE STATE TO [username];
                GRANT VIEW SERVER SECURITY STATE TO [username];
                GRANT VIEW ANY PERFORMANCE DEFINITION TO [username];
                GRANT VIEW ANY SECURITY DEFINITION TO [username];

            For Azure SQL Database the follwing permissions are also granted:
                ALTER SERVER ROLE ##MS_DefinitionReader## ADD MEMBER [username];
                ALTER SERVER ROLE ##MS_SecurityDefinitionReader## ADD MEMBER [username];
                ALTER SERVER ROLE ##MS_ServerStateReader## ADD MEMBER [username];

        In each user database:
            CREATE USER [username] FOR LOGIN [username];
            GRANT VIEW DATABASE STATE TO [username];

    c) User creation using provided scripts (optional):
        In this example the collection user will use SQL Authentication:
            - createUserForAssessmentWithSQLAuth.bat
                The following parameters can be specified:
                    -serverName  ** Required
                    -port  ** Optional (Defaults to 1433)
                    -serverUserName  ** Required
                    -serverUserPass  ** Optional at script level.  Will be prompted if not provided
                    -collectionUserName  ** Required
                    -collectionUserPass  ** Optional at script level.  Will be prompted if not provided

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
                    -collectionUserPass  ** Optional at script level.  Will be prompted if not provided

            For a Named Instance:
                createUserForAssessmentWithWindowsAuth.bat -serverName [servername\instanceName] -port [port number] -collectionUserName [collection user name] -collectionUserPass [collection user password]

            For a Default Instance:
                createUserForAssessmentWithWindowsAuth.bat -serverName [servername] -port [port number] -collectionUserName [collection user name] -collectionUserPass [collection user password]



3. Execution
------------

#### Perfmon Requirements (Optional)

    If you have your own perfmon counters capturing the following statistics or run on a SQL Server Product such as Amazon RDS or Google CloudSQL for SQL Server, skip to step b, otherwise proceed to step a.

    NOTE: Executing Perfmon is OPTIONAL. If not executed the tool will evaluate complexity of migration, but not rightsizing requirements.

    If perfmon is not gathered, skip to step (b).

    Perfmon Counters gahtered:

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

    a) From a command prompt session in "Administrator Mode" on the server you would like to collect data on, execute the following command:

            manageSQLServerPerfmonDataset.bat
            The following parameters can be specified:
                - -operation **Required (create, start, stop, delete, collect, createemptyfile, help)
                - -instanceType **Required (default, named)
                - -namedInstanceName **Required if instanceType is "named" (should be the instance name without the server name)
                - -sampleDuration **The number of intervals that perfmon sample will run defaults to 1152 (10 minute samples for 8 days)
                - -sampleInterval **The interval (in seconds) that perfmon sample will run defaults to 600 (every 10 minutes)

            To execute the perfmon collection:

                For a default instance:
                    manageSQLServerPerfmonDataset.bat -operation create -instanceType default -sampleDuration [number of intervals to sample] -sampleInterval [frequency of sample intervals in seconds]

                For a named instance:
                    manageSQLServerPerfmonDataset.bat -operation create -instanceType named -namedInstanceName [instance name] -sampleDuration [number of intervals to sample] -sampleInterval [frequency of sample intervals in seconds]

        The script will create a permon data set that will collect the above metrics at a 10 minute interval for 8 days.  The dataset will automatically stop after 8 days of collection.  To get the most accurate statistics, it would be good to have this collection run over the busiest time for the server.

    b)  When the perfmon dataset completes or if you would like to execute the collection sooner, execute the following command from a command prompt session in "Administrator Mode" on the server you would like to collect data on
        and return the subsequent .zip file to Google.

        runAssessment.bat
            The following parameters can be specified:
                -serverName ** Required
                -port **Optional (Defaults to 1433)
                -database **Optional (Defaults to all user databases)
                -collectionUserName **Required
                -collectionUserPass **Optional (If not provided will be prompted)
                -ignorePerfmon **Optional (Defaults to "false" / Set to "true" to ignore perfmon collection)
                -manualUniqueId **Optional (Defaults to "NA" - Gives the ability the user to tag their collection with a unique name)
                -collectVMSpecs **Optional switch. See below.

        For a Named Instance (all databases):
            .\runAssessment.bat -serverName [servername\instanceName] -port [port number] -collectionUserName [collection user name] -collectionUserPass [collection user password] -manualUniqueId [string]

                Example (default port): runAssessment.bat -serverName MS-SERVER1 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string]
                Example (custom port): runAssessment.bat -serverName MS-SERVER1 -port 1435 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string]

        For a Named Instance (single database):
            .\runAssessment.bat -serverName [servername\instanceName] -port [port number] -database [database name] -collectionUserName [collection user name] -collectionUserPass [collection user password] -manualUniqueId [string]

                Example (default port): runAssessment.bat -serverName MS-SERVER1/SQL2019 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string]
                Example (custom port): runAssessment.bat -serverName MS-SERVER1 -port 1435 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string]

        For a Default Instance (all databases):
            .\runAssessment.bat -serverName [servername] -port [port number] -collectionUserName [collection user name] -collectionUserPass [collection user password] -manualUniqueId [string]

                Example (default port): runAssessment.bat -serverName MS-SERVER1 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string]
                Example (custom port): runAssessment.bat -serverName MS-SERVER1 -port 1435 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string]

        For a Default Instance (single databases):
            .\runAssessment.bat -serverName [servername] -port [port number] -database [database name] -collectionUserName [collection user name] -collectionUserPass [collection user password] -manualUniqueId [string]

                Example (default port): runAssessment.bat -serverName MS-SERVER1 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string]
                Example (custom port): runAssessment.bat -serverName MS-SERVER1 -port 1435 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string]

        For Azure SQL Database (Ignore Perfmon Collection):
             .\runAssessment.bat -serverName [servername] -port [port number] -database [database name] -collectionUserName [collection user name] -collectionUserPass [collection user password] -ignorePerfmon true -manualUniqueId [string]

                Example (default port): runAssessment.bat -serverName MS-SERVER1 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon true -manualUniqueId [string]
                Example (custom port): runAssessment.bat -serverName MS-SERVER1 -port 1435 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon true -manualUniqueId [string]
                Example (default port / all databases): runAssessment.bat -serverName MS-SERVER1 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon true -manualUniqueId [string]
                Example (custom port / all databases): runAssessment.bat -serverName MS-SERVER1 -port 1435 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon true -manualUniqueId [string]

        Notes:
            1) Google Database Migration Assessment Data Extractor extracts data for all user databases present in the instance
            2) Collection scripts should be executed from an "Administrator Mode" command prompt
            3) When using a port to connect only provide the local host name
            4) The manualUniqueId can be used to give the collection a unique identifier specified by the customer

        CollectVMSpecs:
            To provide rightsizing information the script attempts to connect to the host VM using the current users credentials and collect hardware specs (number of CPUs/amount of memory).
            If the current user does not have sufficient permissions, it will skip this step. To manually input the correct credentials instead when this occurs, specify the -collectVMSpecs switch.
            This is recommended if you plan to upload the results to the Migration Center.

            Example: runAssessment.bat -serverName MS-SERVER1 -collectionUserName sa -collectionUserPass password123 -manualUniqueId [string] -collectVMSpecs

4. Results
----------

    - An archive of the extracted results will be created in the directory collector/output.
    - The full path and file name will be displayed on completion.
    - Return the listed file to Google for processing

!!! IMPORTANT Do not modify the name or the contents of the zip file without consultation from Google.

5. License
------------
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
