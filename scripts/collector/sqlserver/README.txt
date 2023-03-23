README
======
Instructions on how to prepare and run Google Database Migration Assessment Data Extractor for Microsoft SQL Server to extract the data required
for analysis by Database Migration Assessment.

1. Background
-------------

    This utility extracts metadata about the tables, partitions and SQL workload in a database into CSV files.  It also leverages perfmon data that must have a perfmon counter started before the final data collection.  These CSV files are then used by Database Migration Assessment internally to analyze the data with Google Database Migration Assessment.

    a) License Requirements
    -----------------------
    !!! IMPORTANT !!! Google Database Migration Assessment accesses does not require any additional licensing with regards to Microsoft SQL Server.

    b) Database Privileges
    ----------------------
    This utility must be run as a database user with privileges to SELECT from certain data dictionary views.
    The scripts "CreateUserForAssessmentWithSQLAuth.bat" and "CreateUserForAssessmentWithWindowsAuth.bat" are supplied to create the required user and privileges.  Instructions for exeuting it are below.

    c) System Requirements
    ----------------------
    The collection script depends on the following to be available on the machine from which it is run:
    command shell
    powershell
    sqlcmd.exe

2. Preparation
--------------

    a) Unzip the install archive.

    b) Update the sqlserver\sqlqsrv.csv file to contain the full instance name(s) on a separate line you would like to scan in the format:
        [computer name]\[instance name]

        A default instance would look like: MS-SERVER1\MSSQLSERVER

        A custom instance would look like: MS-SERVER1\TESTINSTANCE
    
    c) If the extract will be run by a user that does not have SYSADMIN privilege, connect to the database 
       as a user with SYSADMIN privileges and create the user if needed.

        From a command prompt, execute either of the following scripts depending on what type of authentication you currently use for your SYSADMIN user.  The collection user will use SQL Authentication:
            - CreateUserForAssessmentWithSQLAuth.bat
                The following parameters can be specified:
                    -serverUserName  ** Always Specified
                    -serverUserPass  ** Always Specified
                        and
                    -collectionUserName  ** Specified if a custom username will be used
                    -CollectionUserPass  ** Specified if a custom username will be used
                        or
                    -useDefaultCreds  ** Specify if default credentials coded in the app should be used
            - CreateUserForAssessmentWithWindowsAuth.bat
                The following parameters can be specified:
                    -collectionUserName  ** Specified if a custom username will be used
                    -CollectionUserPass  ** Specified if a custom username will be used
                        or
                    -useDefaultCreds  ** Specify if default credentials coded in the app should be used

3. Execution
------------
    If you have your own perfmon counters capturing the following statistics, skip to step b, otherwise proceed to step a.

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


    a) From a powershell session on the server you would like to collect data on, execute the following command:
    
        For a default instance:
            .\ManageSqlServerPerfmonDatset.bat -operation create

        For a named instance:
            .\ManageSqlServerPerfmonDatset.bat -operation create -mssqlInstanceName [instance name]

        The script will create a permon data set that will collect the above metrics at a 1 minute interval for 8 days.  The dataset will automatically stop after 8 days of collection.  To get the most accurate statistics, it would be good to have this collection run over the busiest time for the server.

    b)  When the perfmon dataset completes or if you would like to execute the collection sooner, execute the following command and return the subsequent .zip file to Google.

        If a custom collection user was created in the above step:
            .\RunAssessment.bat -username [collection user name] -password [collection user password]

        If the default user was created in the above step:
            .\RunAssessment.bat -useDefaultCreds

        Notes:
            1) Google Database Migration Assessment Data Extractor extracts data for the entire database.

4. Results
----------

    An archive of the extracted results will be created in the directory collector/output. 
    The full path and file name will be displayed on completion.

5. License
------------
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