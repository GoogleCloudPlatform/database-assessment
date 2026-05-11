# Gather workload metadata
-Instructions on how to prepare and run Google Database Migration Assessment Data Extractor for Microsoft SQL Server to extract the data required for analysis.

This utility extracts metadata about the tables, partitions and SQL workload in a database into CSV files. It also leverages perfmon data that must have a perfmon counter started before the final data collection. These CSV files are then used by Database Migration Assessment to help provide guidance on rightsizing, modernization or migration to Google Cloud Services.

The workload collection supports the following:

**SQL Server Versions:**
- SQL Server 2008 (SP4-GDR) (KB5020863) - 10.0.6814.4 (X64) through SQL Server 2022
- AZURE SQL Database

**Operating System Versions:**
- Windows Server 2012 through Windows Server 2022 (Requires PowerShell Version 5 or Greater)

## System environment

The collection script depends on the following executables to be available on the machine from which it is run. The script is also expected to be run from a Windows machine in "Administrator Mode":

```shell
command prompt
powershell (version 5 or greater)
sqlcmd (version 11.0.7512.11 or greater)
```

If needed sqlcmd can be downloaded from [here](https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility?view=sql-server-ver16&tabs=odbc%2Cwindows#download-and-install-sqlcmd)

!!! note
    Ensure that the `ODBC` version of `sqlcmd` is used. The `GO` version of `sqlcmd` will not work.
    Ensure that `sqlcmd` is also in your `$PATH` variable.

## Execute collection script

Download the latest collection scripts [here](https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-sqlserver.zip).

```shell
mkdir ./dbma_collector && cd dbma_collector
# Download and unzip the archive
unzip db-migration-assessment-collection-scripts-sqlserver.zip
```

- Execute this from a system that can access your database via sqlcmd.
- Execute from a user with sufficient privileges or optionally use the provided creation script.
- See the [Permissions Required](permissions.md) and [Database User Scripts](db_user_create.md) pages for details.

### Perfmon Requirements (Optional)

!!! note
    Executing Perfmon is OPTIONAL. If not executed the tool will evaluate complexity of migration, but not rightsizing requirements.
    The standard perfmon collector collects every 10 minutes for 8 days.

If you have your own perfmon counters capturing the following statistics or run on a SQL Server Product such as Amazon RDS or Google CloudSQL for SQL Server, skip to step b, otherwise proceed to step a.
The Perfmon data collection process is optional and can be safely skipped. However, there will be no right sizing information in the assessment report.

The following counters are gathered:

- **\Memory\Available MBytes**: Total amount of available memory on the system.
- **\PhysicalDisk(_Total)\Avg. Disk Bytes/Read**: Average size of read operations on a volume in bytes.
- **\PhysicalDisk(_Total)\Avg. Disk Bytes/Write**: Average size of write operations on a volume in bytes.
- **\PhysicalDisk(_Total)\Avg. Disk sec/Read**: Average time in seconds it takes to read data from a disk.
- **\PhysicalDisk(_Total)\Avg. Disk sec/Write**: Average time in seconds it takes to write data to a disk.
- **\PhysicalDisk(_Total)\Disk Reads/sec**: Read IOPS from a file per second.
- **\PhysicalDisk(_Total)\Disk Writes/sec**: Write IOPS to a file per second.
- **\Processor(_Total)\% Idle Time**: Percentage of time a processor spends on idle threads.
- **\Processor(_Total)\% Processor Time**: Percentage of time a processor spends executing non-idle threads.
- **\Processor Information(_Total)\Processor Frequency**: Processor frequency.
- **\System\Processor Queue Length**: Number of threads that are ready to execute but waiting for a core to become available.
- **\SQLServer:Buffer Manager\Buffer cache hit ratio**: Percentage of pages found in memory without having to be read from disk.
- **\SQLServer:Buffer Manager\Checkpoint pages/sec**: Number of dirty pages moved from the SQL buffer pool to disk during a checkpoint.
- **\SQLServer:Buffer Manager\Free list stalls/sec**: Requests per second waiting for a free page.
- **\SQLServer:Buffer Manager\Page life expectancy**: Indicates memory pressure in allocated memory.
- **\SQLServer:Buffer Manager\Page lookups/sec**: Number of requests to find a page in the buffer pool.
- **\SQLServer:Buffer Manager\Page reads/sec**: Rate at which the disk is read to resolve page faults.
- **\SQLServer:Buffer Manager\Page writes/sec**: Rate at which page data is written to the disk.
- **\SQLServer:General Statistics\User Connections**: Number of current connections to SQL Server.
- **\SQLServer:Memory Manager\Memory Grants Pending**: Total number of SQL Server processes waiting for workspace memory.
- **\SQLServer:Memory Manager\Target Server Memory (KB)**: Amount of memory that SQL Server can potentially consume.
- **\SQLServer:Memory Manager\Total Server Memory (KB)**: Amount of memory the server has committed.
- **\SQLServer:SQL Statistics\Batch Requests/sec**: Number of T-SQL commands received by the server per second.
- **\NUMA Node Memory(_Total)\Total MBytes**: Total amount of physical memory associated with a NUMA node.
- **\NUMA Node Memory(_Total)\Available MBytes**: Free amount of physical memory associated with a NUMA node.
- **\Process(_Total)\IO Read Operations/sec**: Rate at which a process issues read I/O operations.
- **\Process(_Total)\IO Write Operations/sec**: Rate at which a process issues write I/O operations.
- **\Process(_Total)\IO Read Bytes/sec**: Rate at which a process reads bytes in I/O operations.
- **\Process(_Total)\IO Write Bytes/sec**: Rate at which a process writes bytes in I/O operations.

From a command prompt session in "Administrator Mode" on the server you would like to collect data on, execute the following command:

**To create and start the perfmon collection:**

For a default instance:
```shell
manageSQLServerPerfmonDataset.bat -operation create -instanceType default -sampleDuration [number of intervals to sample] -sampleInterval [frequency of sample intervals in seconds]
```

For a named instance:
```shell
manageSQLServerPerfmonDataset.bat -operation create -instanceType named -namedInstanceName [instance name] -sampleDuration [number of intervals to sample] -sampleInterval [frequency of sample intervals in seconds]
```

The script will create a perfmon data set that will collect metrics at 10 minute intervals for 8 days.

### Perform Collection

When the perfmon dataset completes or if you would like to execute the collection sooner, execute `runAssessment.bat` from an "Administrator Mode" command prompt.

```shell
runAssessment.bat -serverName [servername] -port [port number] -collectionUserName [collection user name] -collectionUserPass [collection user password] -manualUniqueId [string]
```

**Examples:**

For a default instance (all databases):
```shell
runAssessment.bat -serverName MS-SERVER1 -collectionUserName sa -collectionUserPass password123 -manualUniqueId MyCol1
```

For a named instance:
```shell
runAssessment.bat -serverName MS-SERVER1/SQL2019 -collectionUserName sa -collectionUserPass password123 -manualUniqueId MyCol1
```

For Azure SQL Database (Ignore Perfmon Collection):
```shell
runAssessment.bat -serverName [servername] -database [database name] -collectionUserName [collection user name] -collectionUserPass [collection user password] -ignorePerfmon true -manualUniqueId MyCol1
```

#### CollectVMSpecs

To provide rightsizing information the script attempts to collect hardware specs. If the current user does not have sufficient permissions, specify the `-collectVMSpecs` switch to manually input credentials.

```shell
runAssessment.bat -serverName MS-SERVER1 -collectionUserName sa -collectionUserPass password123 -manualUniqueId MyCol1 -collectVMSpecs
```

## Digitally Signing Powershell Scripts (Optional)

Occasionally, organizational security policies require that Powershell scripts be digitally signed. You can create a self-signed certificate and sign the scripts using the following steps in Powershell:

```powershell
# Create self-signed certificate
$params = @{
    Subject = 'Google DMA Self Signed PS Code Signing'
    DnsName = 'Self@google.com'
    Type = 'CodeSigning'
    CertStoreLocation = 'cert:\CurrentUser\My'
}
$newCodeSigningCert = New-SelfSignedCertificate @params

# Export and Import to Trusted Root
Export-Certificate -Cert "cert:\CurrentUser\My\$($newCodeSigningCert.Thumbprint)" -FilePath "./CodeSigning.cer"
Import-Certificate -FilePath "./CodeSigning.cer" -Cert Cert:\LocalMachine\root

# Sign all DMA Scripts
Get-ChildItem -Filter *.ps1,*.psm1 | ForEach-Object {
    Set-AuthenticodeSignature $_.FullName -Certificate $newCodeSigningCert
}
```

## License Requirements

Google Database Migration Assessment does not require any additional licensing with regards to Microsoft SQL Server.

## Upload Collections

Upon completion, the tool will automatically create an archive of the extracted metrics in the `collector/output` directory. Do not modify the file names or contents. Return the listed file to Google for processing.
