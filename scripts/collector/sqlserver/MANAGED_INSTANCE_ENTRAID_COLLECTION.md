# Azure SQL Managed Instance Collection with Entra ID MFA

This collector supports Azure SQL Managed Instance collection using Microsoft Entra ID MFA. In this mode, do not pass a SQL collection username or password. The collector opens one persistent ODBC connection using the Entra ID user you provide, then reuses that connection for the SQL metadata queries.

## Required PowerShell Modules

The following PowerShell modules are required before running the Managed Instance Entra ID collection path:

```text
Az.Accounts
SqlServer
```

The `SqlServer` module must be version `22.3.0`. Remove other installed versions and install the required version:

```powershell
Uninstall-Module -Name SqlServer -AllVersions
Install-Module -Name SqlServer -RequiredVersion 22.3.0 -Force -AllowClobber
```

Install `Az.Accounts` if it is not already installed:

```powershell
Install-Module -Name Az.Accounts -Force -AllowClobber
```

## Required Parameters

`-serverName`

The Managed Instance endpoint.

For a public endpoint this is usually the full public DNS name, for example:

```text
<managed-instance-name>.public.<dns-zone>.database.windows.net
```

`-port`

For Azure SQL Managed Instance public endpoint access, use:

```text
3342
```

For private endpoint/VNet access, use the port configured for that endpoint, commonly `1433`.

`-useEntraIDAuthentication`

Enables the Managed Instance Entra ID MFA path. This must be supplied for Entra ID authentication.

`-entraIDUserName`

The Entra ID account used for MFA sign-in. Example:

```text
user@domain.com
```

This is not a SQL collection user. No password is passed to the collector.

## Common Optional Parameters

`-ignorePerfmon true`

Recommended for Azure SQL Managed Instance. Perfmon and host VM collection are not available from the managed service host.

`-database`

Optional. Defaults to `all`. Use this to collect a single database:

```text
-database AdventureWorks
```

`-manualUniqueId`

Optional label written into output files. If supplied, use only letters and numbers, no spaces or special characters.

Example:

```text
-manualUniqueId SQLMI001
```

## Do Not Pass These with Entra ID Auth

Do not pass:

```text
-collectionUserName
-collectionUserPass
-useWindowsAuthentication
```

Those are for SQL authentication or Windows authentication collection paths, not Managed Instance Entra ID MFA.

## Example Command

Run from this directory:

```text
C:\DMA\database-assessment\scripts\collector\sqlserver
```

Command:

```bat
.\runAssessment.bat -serverName <managed-instance-name>.public.<dns-zone>.database.windows.net -port 3342 -ignorePerfmon true -useEntraIDAuthentication -entraIDUserName user@domain.com
```

With a manual ID:

```bat
.\runAssessment.bat -serverName <managed-instance-name>.public.<dns-zone>.database.windows.net -port 3342 -ignorePerfmon true -manualUniqueId SQLMI001 -useEntraIDAuthentication -entraIDUserName user@domain.com
```

For one database only:

```bat
.\runAssessment.bat -serverName <managed-instance-name>.public.<dns-zone>.database.windows.net -port 3342 -database AdventureWorks -ignorePerfmon true -useEntraIDAuthentication -entraIDUserName user@domain.com
```

## Expected Behavior

The collector prompts to acknowledge that Perfmon data will not be collected when `-ignorePerfmon true` is used. Type:

```text
Y
```

An Entra ID MFA sign-in prompt opens for the supplied `-entraIDUserName`. Complete the sign-in. The collector then reuses the same authenticated connection for the metadata collection.

On success, the collector writes a zip file in the SQL Server collector directory and prints a line similar to:

```text
Return file C:\DMA\database-assessment\scripts\collector\sqlserver\opdb_mssql_NoPerfCounter__...zip
```

## Verified Managed Instance Test

This path was verified against:

```text
<managed-instance-name>.public.<dns-zone>.database.windows.net,3342
```

using:

```text
-useEntraIDAuthentication -entraIDUserName user@domain.com
```

The collector completed and produced an assessment zip.
