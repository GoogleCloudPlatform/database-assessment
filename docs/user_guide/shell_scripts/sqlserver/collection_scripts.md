# Gather workload metadata

Instructions on how to prepare and run Google Database Migration Assessment Data Extractor for Microsoft SQL Server to extract the data required for analysis.

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
    Ensure that the `ODBC` version of `sqlcmd` is used.  The `GO` version of `sqlcmd` will not work.
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
