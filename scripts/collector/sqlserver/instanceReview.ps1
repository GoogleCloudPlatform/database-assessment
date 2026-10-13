# Author: Tim Chapman
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
<#
.SYNOPSIS
    .
.DESCRIPTION
    Executes the necessary scripts to collect data from SQL Server and Perfmon to be uploaded to Google Database Migration Assistant for review.

    If user and password are supplied, that will be used to execute the script.  Otherwise default credentials hardcoded in the script will be used
.PARAMETER serverName
    Connection string usually in the form of [server name / ip address]\[instance name] (required)
.PARAMETER port
    Connection port (default:1433 / optional)
.PARAMETER database
    Run assessment for a single database (default:all / optional)
.PARAMETER collectionUserName
    Collection username (required)
.PARAMETER collectionUserPass
    Collection username password (required)
.PARAMETER entraIDUserName
    Microsoft Entra ID username used with sqlcmd -G -U for MFA authentication. No password is supplied.
.PARAMETER ignorePerfmon
    Signals if the perfmon collection should be skipped (default:false)
.PARAMETER manualUniqueId
    Tag that can be supplied by the customer to make a collection unique.  Maps to the internal variable dmaManualId (optional)
.PARAMETER collectVMSpecs
    Whether to explicitly request credentials to collect data from the VM hosting the DB if the current users credentials are not sufficient.
    Note the script will attempt to collect VM specs using the current users regardless. (default:false)
.PARAMETER useWindowsAuthentication
    Specifies if the logging to the database will utilize the current Windows Authenticated User or the supplied username / password for SQL Authentication (default:false)
.PARAMETER useEntraIDAuthentication
    Specifies if SQL connections will use Microsoft Entra ID authentication through sqlcmd -G -U. This does not use collection username / password parameters.
.PARAMETER outputDirectory
    User specified output directory if desired to be different from the $PSScriptRoot default
.EXAMPLE
    To use a specific username / password combination for a named instance:
        instanceReview.ps1 -serverName [server name / ip address]\[instance name] -collectionUserName [collection username] -collectionUserPass [collection username password] -ignorePerfmon [true/false] -dmaManualId [string]

    To use a specific username / password combination for a default instance:
        instanceReview.ps1 -serverName [server name / ip address] -collectionUserName [collection username] -collectionUserPass [collection username password] -ignorePerfmon [true/false] -dmaManualId [string]

.NOTES
    https://googlecloudplatform.github.io/database-assessment/
#>
Param(
    [Parameter(Mandatory = $true)][string]$serverName = "",
    [Parameter(Mandatory = $false)][string]$port = "default",
    [Parameter(Mandatory = $false)][string]$database = "all",
    [Parameter(Mandatory = $false)][string]$collectionUserName,
    [Parameter(Mandatory = $false)][string]$collectionUserPass,
    [Parameter(Mandatory = $false)][string]$entraIDUserName,
    [Parameter(Mandatory = $false)][string]$ignorePerfmon = "false",
    [Parameter(Mandatory = $false)][string]$manualUniqueId = "NA",
    [Parameter(Mandatory = $false)][switch]$collectVMSpecs,
    [Parameter(Mandatory = $false)][switch]$useWindowsAuthentication = $false,
    [Parameter(Mandatory = $false)][switch]$useEntraIDAuthentication = $false,
    [Parameter(Mandatory = $false)][string]$outputDirectory = "default"
)

Import-Module $PSScriptRoot\dmaCollectorCommonFunctions.psm1

$script:CollectionStartTime = Get-Date
$script:BootstrapLogFile = Join-Path $PSScriptRoot "dma_collector_bootstrap.log"
$script:StepTelemetry = @()
$script:StepExecutionErrors = @()
$script:PermissionWarnings = @()
$script:CsvManifestStats = @()

function Write-DmaBootstrapLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $false)][string]$Level = "INFO"
    )
    $ts = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    $entry = "$ts [$Level] $Message"
    try {
        Add-Content -Path $script:BootstrapLogFile -Encoding utf8 -Value $entry -ErrorAction SilentlyContinue
    }
    catch {}
}

try {
    $bootstrapHeader = @(
        "================================================================================",
        "               DMA SQL Server Collector Bootstrap & Execution Log               ",
        "================================================================================",
        "Started At:          $($script:CollectionStartTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))",
        "Host Computer:       $env:COMPUTERNAME",
        "Current Windows ID:  $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)",
        "Working Directory:   $((Get-Location).Path)",
        "Script Root:         $PSScriptRoot",
        "PowerShell Version:  $($PSVersionTable.PSVersion)",
        "Windows OS Version:  $([Environment]::OSVersion.VersionString)",
        "Parameters:          serverName='$serverName' port='$port' database='$database' collectionUserName='$collectionUserName' collectionUserPass='$(if ([string]::IsNullOrEmpty($collectionUserPass)) { '<empty>' } else { '********' })' useWindowsAuthentication=$useWindowsAuthentication useEntraIDAuthentication=$useEntraIDAuthentication entraIDUserName='$entraIDUserName' ignorePerfmon='$ignorePerfmon' collectVMSpecs=$collectVMSpecs manualUniqueId='$manualUniqueId' outputDirectory='$outputDirectory'",
        "================================================================================"
    ) -join [Environment]::NewLine
    Set-Content -Path $script:BootstrapLogFile -Encoding utf8 -Value $bootstrapHeader -ErrorAction SilentlyContinue
}
catch {}

trap {
    $trappedError = $_
    $ts = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    $stmtLine = if ($trappedError.InvocationInfo -and $trappedError.InvocationInfo.Line) { $trappedError.InvocationInfo.Line.Trim() } else { "N/A" }
    Write-Host ""
    Write-Host "================================================================================" -ForegroundColor Red
    Write-Host "$ts [FATAL ERROR] instanceReview.ps1 encountered an unhandled exception!" -ForegroundColor Red
    Write-Host "Exception: $($trappedError.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Message:   $($trappedError.Exception.Message)" -ForegroundColor Red
    Write-Host "Location:  $($trappedError.InvocationInfo.ScriptName):$($trappedError.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host "Statement: $stmtLine" -ForegroundColor Red
    Write-Host "================================================================================" -ForegroundColor Red

    $crashReport = @(
        "FATAL SCRIPT ERROR AT: $ts",
        "Exception: $($trappedError.Exception.GetType().FullName)",
        "Message:   $($trappedError.Exception.Message)",
        "Location:  $($trappedError.InvocationInfo.ScriptName):$($trappedError.InvocationInfo.ScriptLineNumber)",
        "Statement: $stmtLine",
        "",
        "Stack Trace:",
        "$($trappedError.ScriptStackTrace)"
    ) -join [Environment]::NewLine

    Write-DmaBootstrapLog -Level "FATAL" -Message $crashReport
    try {
        Set-Content -Path (Join-Path $PSScriptRoot "CRASH_REPORT.txt") -Encoding utf8 -Value $crashReport -ErrorAction SilentlyContinue
    }
    catch {}

    if (-not [string]::IsNullOrEmpty($foldername) -and (Test-Path -Path $foldername)) {
        Set-Content -Path "$foldername\CRASH_REPORT.txt" -Encoding utf8 -Value $crashReport
        if (-not [string]::IsNullOrEmpty($logFile)) {
            Add-Content -Path "$foldername\$logFile" -Encoding utf8 -Value $crashReport -ErrorAction SilentlyContinue
        }
    }
    continue
}

function Get-DmaAzureSqlAccessToken {
    $sqlServerModule = Get-Module -ListAvailable SqlServer | Sort-Object Version -Descending | Select-Object -First 1
    if ($null -ne $sqlServerModule) {
        $sqlServerModulePath = Split-Path $sqlServerModule.Path
        $msalDll = Get-ChildItem -Path $sqlServerModulePath -Recurse -Filter "Microsoft.Identity.Client.dll" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        if (-not [string]::IsNullOrEmpty($msalDll)) {
            Add-Type -Path $msalDll -ErrorAction SilentlyContinue

            $clientId = "04f0c124-f2bc-4f59-8241-bf6df9866bbd"
            $authority = "https://login.microsoftonline.com/common"
            $scopes = [string[]]@("https://database.windows.net//.default")
            $redirectUri = "http://localhost"

            Write-Host "Launching Microsoft Entra interactive sign-in for Azure SQL..."
            $app = [Microsoft.Identity.Client.PublicClientApplicationBuilder]::Create($clientId).WithAuthority($authority).WithRedirectUri($redirectUri).Build()
            try {
                $result = $app.AcquireTokenInteractive($scopes).ExecuteAsync().GetAwaiter().GetResult()
                if (-not [string]::IsNullOrEmpty($result.AccessToken)) {
                    return $result.AccessToken
                }
            }
            catch {
                Write-Host "Microsoft Entra interactive token acquisition failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    if (Get-Command az -ErrorAction SilentlyContinue) {
        $azAccount = az account show 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "No Azure CLI session found. Launching az login..."
            az login --allow-no-subscriptions
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Azure login failed. Exiting." -ForegroundColor Red
                Exit 1
            }
        }

        $token = az account get-access-token --resource https://database.windows.net/ --query accessToken -o tsv 2>$null
        if ($LASTEXITCODE -eq 0 -and (-not [string]::IsNullOrEmpty($token))) {
            return $token.Trim()
        }
    }

    if (Get-Module -ListAvailable Az.Accounts) {
        try {
            Import-Module Az.Accounts -ErrorAction Stop
            if ($null -eq (Get-AzContext -ErrorAction SilentlyContinue)) {
                Connect-AzAccount -ErrorAction Stop | Out-Null
            }

            $tokenResult = Get-AzAccessToken -ResourceUrl https://database.windows.net/ -ErrorAction Stop
            if ($tokenResult.Token -is [securestring]) {
                return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenResult.Token))
            }
            return [string]$tokenResult.Token
        }
        catch {
            Write-Host "Az.Accounts token acquisition failed." -ForegroundColor Yellow
            Write-Host "    $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    Write-Host "Entra ID authentication with Invoke-Sqlcmd could not acquire an Azure SQL access token." -ForegroundColor Red
    Write-Host "Install Azure CLI and run az login, install Az.Accounts and run Connect-AzAccount, or use the modern SqlServer module that includes Microsoft.Identity.Client.dll." -ForegroundColor Red
    Exit 1
}

function Convert-DmaSqlcmdValue {
    param([object]$Value)

    if ($null -eq $Value -or $Value -is [DBNull]) {
        return ""
    }
    return [string]$Value
}

function Format-DmaInvokeSqlcmdRows {
    param(
        [Parameter(ValueFromPipeline = $true)]$Rows,
        [string]$Separator = " "
    )

    process {
        foreach ($row in @($Rows)) {
            if ($null -eq $row) {
                continue
            }

            if ($row -is [System.Data.DataRow]) {
                $values = foreach ($column in $row.Table.Columns) {
                    Convert-DmaSqlcmdValue -Value $row[$column.ColumnName]
                }
                $values -join $Separator
            }
            elseif ($row -is [System.Data.DataTable]) {
                foreach ($dataRow in $row.Rows) {
                    $values = foreach ($column in $row.Columns) {
                        Convert-DmaSqlcmdValue -Value $dataRow[$column.ColumnName]
                    }
                    $values -join $Separator
                }
            }
            else {
                $properties = $row.PSObject.Properties | Where-Object { $_.MemberType -in @("Property", "NoteProperty") }
                if ($properties.Count -eq 0) {
                    [string]$row
                }
                else {
                    ($properties | ForEach-Object { Convert-DmaSqlcmdValue -Value $_.Value }) -join $Separator
                }
            }
        }
    }
}

function Convert-DmaSqlcmdVariableValue {
    param([string]$Value)

    if ($null -eq $Value) {
        return ""
    }

    $trimmedValue = $Value.Trim()
    if ($trimmedValue.Length -ge 2 -and $trimmedValue.StartsWith('"') -and $trimmedValue.EndsWith('"')) {
        return $trimmedValue.Substring(1, $trimmedValue.Length - 2)
    }
    return $Value
}

function Initialize-DmaEntraOdbcConnection {
    param(
        [Parameter(Mandatory = $true)][string]$ServerInstance,
        [Parameter(Mandatory = $true)][string]$DatabaseName
    )

    if ($null -ne $script:DmaEntraOdbcConnection -and $script:DmaEntraOdbcConnection.State -eq [System.Data.ConnectionState]::Open) {
        return
    }

    $connectionString = "Driver={ODBC Driver 17 for SQL Server};Server=$ServerInstance;Database=$DatabaseName;Authentication=ActiveDirectoryInteractive;UID=$script:DmaEntraIDUserName;Encrypt=yes;TrustServerCertificate=yes;Connection Timeout=30;"
    $script:DmaEntraOdbcConnection = [System.Data.Odbc.OdbcConnection]::new($connectionString)
    $script:DmaEntraOdbcConnection.Open()
}

function Invoke-DmaEntraSql {
    param(
        [Parameter(Mandatory = $true)][string]$ServerInstance,
        [Parameter(Mandatory = $false)][string]$DatabaseName = "master",
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $false)][string]$Separator = " ",
        [Parameter(Mandatory = $false)][bool]$IncludeHeaders = $true,
        [Parameter(Mandatory = $false)][hashtable]$Variables = @{}
    )

    $DatabaseName = (Convert-DmaSqlcmdVariableValue -Value $DatabaseName)
    if ([string]::IsNullOrEmpty($DatabaseName)) {
        $DatabaseName = "master"
    }

    Initialize-DmaEntraOdbcConnection -ServerInstance $ServerInstance -DatabaseName $DatabaseName

    $sqlText = Get-Content -Path $InputFile -Raw
    foreach ($key in $Variables.Keys) {
        $sqlText = $sqlText.Replace('$(' + $key + ')', [string]$Variables[$key])
    }

    if ($script:DmaEntraOdbcConnection.Database -ne $DatabaseName) {
        $script:DmaEntraOdbcConnection.ChangeDatabase($DatabaseName)
    }

    $command = $script:DmaEntraOdbcConnection.CreateCommand()
    $command.CommandTimeout = 0
    $command.CommandText = $sqlText

    $adapter = [System.Data.Odbc.OdbcDataAdapter]::new($command)
    $dataSet = [System.Data.DataSet]::new()
    [void]$adapter.Fill($dataSet)

    foreach ($table in $dataSet.Tables) {
        if ($IncludeHeaders) {
            $headers = foreach ($column in $table.Columns) {
                $column.ColumnName
            }
            $headers -join $Separator
        }
        foreach ($row in $table.Rows) {
            $values = foreach ($column in $table.Columns) {
                Convert-DmaSqlcmdValue -Value $row[$column.ColumnName]
            }
            $values -join $Separator
        }
    }
}

function sqlcmd {
    $SqlcmdArgs = $args

    if (-not $script:UseEntraOdbcForSqlcmd) {
        & $script:NativeSqlcmdPath @SqlcmdArgs
        return
    }

    $serverInstance = $null
    $databaseName = "master"
    $inputFile = $null
    $separator = " "
    $includeHeaders = $true
    $variables = @{}

    for ($i = 0; $i -lt $SqlcmdArgs.Count; $i++) {
        $arg = [string]$SqlcmdArgs[$i]
        switch -Regex ($arg) {
            '^-S$' {
                $i++
                $serverInstance = [string]$SqlcmdArgs[$i]
                continue
            }
            '^-d$' {
                $i++
                $databaseName = [string]$SqlcmdArgs[$i]
                continue
            }
            '^-i$' {
                $i++
                $inputFile = [string]$SqlcmdArgs[$i]
                continue
            }
            '^-h-1$' {
                $includeHeaders = $false
                continue
            }
            '^-h$' {
                $i++
                if ([string]$SqlcmdArgs[$i] -eq "-1") {
                    $includeHeaders = $false
                }
                continue
            }
            '^-s(.+)$' {
                $separator = $Matches[1].Trim('"')
                continue
            }
            '^-s$' {
                $i++
                $separator = ([string]$SqlcmdArgs[$i]).Trim('"')
                continue
            }
            '^-v$' {
                while (($i + 1) -lt $SqlcmdArgs.Count) {
                    $nextArg = [string]$SqlcmdArgs[$i + 1]
                    if ($nextArg -match '^-' -and $nextArg -notmatch '=') {
                        break
                    }
                    $nameValue = $nextArg -split '=', 2
                    if ($nameValue.Count -eq 2) {
                        $variables[$nameValue[0]] = Convert-DmaSqlcmdVariableValue -Value $nameValue[1]
                    }
                    $i++
                }
                continue
            }
        }
    }

    if ([string]::IsNullOrEmpty($serverInstance) -or [string]::IsNullOrEmpty($inputFile)) {
        throw "The internal Entra ID sqlcmd wrapper could not parse the sqlcmd arguments: $($SqlcmdArgs -join ' ')"
    }

    Invoke-DmaEntraSql -ServerInstance $serverInstance -DatabaseName $databaseName -InputFile $inputFile -Separator $separator -IncludeHeaders $includeHeaders -Variables $variables
}

function Invoke-DmaSqlStep {
    param(
        [Parameter(Mandatory = $true)][string]$StepName,
        [Parameter(Mandatory = $true)][string]$SqlFile,
        [Parameter(Mandatory = $true)][string]$DatabaseName,
        [Parameter(Mandatory = $true)][string]$OutputFilePath,
        [Parameter(Mandatory = $false)][string[]]$SqlcmdVars = @()
    )
    $outLeaf = Split-Path -Leaf $OutputFilePath
    WriteLog -logLocation $foldername\$logFile -logMessage "[STEP-START] $StepName | SQL=$SqlFile | DB=$DatabaseName | Out=$outLeaf" -logOperation "BOTH"

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $cmdArgs = @('-S', $serverName, '-i', $SqlFile, '-d', $DatabaseName, '-C', '-l', '30', '-W', '-m', '1', '-u', '-h-1', '-w', '32768')
    if ($SqlcmdVars -and $SqlcmdVars.Count -gt 0) {
        $cmdArgs += '-v'
        $cmdArgs += $SqlcmdVars
    }
    $cmdArgs += '-s|'
    if ($sqlcmdAuthArgs -and $sqlcmdAuthArgs.Count -gt 0) {
        $cmdArgs += $sqlcmdAuthArgs
    }

    $rawOutput = @()
    $exitCode = 0
    $caughtException = $null
    try {
        $rawOutput = @(sqlcmd @cmdArgs 2>&1)
        if ($null -ne $LASTEXITCODE) {
            $exitCode = [int]$LASTEXITCODE
        }
    }
    catch {
        $caughtException = $_
        $exitCode = -1
    }
    $sw.Stop()

    $dataLines = New-Object System.Collections.Generic.List[string]
    $errorLines = New-Object System.Collections.Generic.List[string]
    $inSqlErrorBlock = $false

    if ($null -ne $caughtException) {
        $errorLines.Add("Exception: $($caughtException.Exception.Message)")
    }

    foreach ($item in $rawOutput) {
        if ($null -eq $item) { continue }
        $lineStr = [string]$item
        if ($item -is [System.Management.Automation.ErrorRecord]) {
            if (-not [string]::IsNullOrWhiteSpace($lineStr)) {
                $errorLines.Add($lineStr.Trim())
            }
            continue
        }
        if ($lineStr -match '^[\s\-|]+$') {
            continue
        }
        if ($lineStr -match '^\s*(Msg\s+\d+,\s*Level\s+\d+,\s*State\s+\d+|Sqlcmd:\s*Error:|HResult\s+0x)') {
            $inSqlErrorBlock = $true
            $errorLines.Add($lineStr.Trim())
            continue
        }
        if ($inSqlErrorBlock) {
            if ($lineStr.Contains('|')) {
                $inSqlErrorBlock = $false
                $dataLines.Add($lineStr)
            }
            elseif (-not [string]::IsNullOrWhiteSpace($lineStr)) {
                $errorLines.Add($lineStr.Trim())
            }
            continue
        }
        $dataLines.Add($lineStr)
    }

    if ($dataLines.Count -gt 0) {
        Add-Content -Path $OutputFilePath -Encoding utf8 -Value $dataLines
    }

    $rowsAdded = $dataLines.Count
    $hasStepError = ($errorLines.Count -gt 0) -or ($exitCode -ne 0)
    $status = if ($hasStepError) { "ERROR" } else { "OK" }
    $errSummary = if ($errorLines.Count -gt 0) { ($errorLines -join " | ") } elseif ($exitCode -ne 0) { "sqlcmd exited with code $exitCode" } else { "" }

    if ($hasStepError) {
        WriteLog -logLocation $foldername\$logFile -logMessage "[STEP-ERROR] $StepName | SQL=$SqlFile | DB=$DatabaseName | Out=$outLeaf | DurationMs=$($sw.ElapsedMilliseconds) | ExitCode=$exitCode | RowsAdded=$rowsAdded | Error=$errSummary" -logOperation "BOTH"
        WriteLog -logLocation $foldername\$sqlErrorLogFile -logMessage "[STEP-ERROR] $StepName ($SqlFile on $DatabaseName -> $outLeaf): $errSummary" -logOperation "FILE"
        $script:StepExecutionErrors += [PSCustomObject]@{
            StepName = $StepName
            SqlFile  = $SqlFile
            Database = $DatabaseName
            File     = $outLeaf
            Error    = $errSummary
        }
    }
    else {
        WriteLog -logLocation $foldername\$logFile -logMessage "[STEP-DONE]  $StepName | SQL=$SqlFile | DB=$DatabaseName | Out=$outLeaf | DurationMs=$($sw.ElapsedMilliseconds) | ExitCode=$exitCode | RowsAdded=$rowsAdded" -logOperation "BOTH"
    }

    $script:StepTelemetry += [PSCustomObject]@{
        StepName   = $StepName
        SqlFile    = $SqlFile
        Database   = $DatabaseName
        OutputFile = $outLeaf
        DurationMs = $sw.ElapsedMilliseconds
        ExitCode   = $exitCode
        RowsAdded  = $rowsAdded
        Status     = $status
        ErrorText  = $errSummary
    }
}

function Invoke-DmaPermissionAudit {
    WriteLog -logLocation $foldername\$logFile -logMessage "Running Pre-Flight SQL Server Permission & Security Context Audit..." -logOperation "BOTH"
    $auditSqlPath = Join-Path $foldername "_dma_perm_audit.sql"
    $auditSql = @'
SET NOCOUNT ON;
SELECT 'IDENTITY_LOGIN', ISNULL(SUSER_SNAME(), N'NULL');
SELECT 'IDENTITY_ORIGINAL_LOGIN', ISNULL(ORIGINAL_LOGIN(), N'NULL');
SELECT 'IDENTITY_USER', ISNULL(USER_NAME(), N'NULL');
SELECT 'ROLE_SYSADMIN', CAST(ISNULL(IS_SRVROLEMEMBER('sysadmin'), 0) AS VARCHAR(10));
SELECT 'ROLE_SECURITYADMIN', CAST(ISNULL(IS_SRVROLEMEMBER('securityadmin'), 0) AS VARCHAR(10));
SELECT 'ROLE_SERVERADMIN', CAST(ISNULL(IS_SRVROLEMEMBER('serveradmin'), 0) AS VARCHAR(10));
SELECT 'ROLE_PROCESSADMIN', CAST(ISNULL(IS_SRVROLEMEMBER('processadmin'), 0) AS VARCHAR(10));
SELECT 'PERM_VIEW_SERVER_STATE', CAST(ISNULL(HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE'), 0) AS VARCHAR(10));
SELECT 'PERM_VIEW_ANY_DEFINITION', CAST(ISNULL(HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW ANY DEFINITION'), 0) AS VARCHAR(10));
SELECT 'PERM_VIEW_ANY_DATABASE', CAST(ISNULL(HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW ANY DATABASE'), 0) AS VARCHAR(10));
SELECT 'PERM_XP_READERRORLOG', CAST(ISNULL(HAS_PERMS_BY_NAME('master.dbo.xp_readerrorlog', 'OBJECT', 'EXECUTE'), 0) AS VARCHAR(10));
BEGIN TRY
    EXEC(N'
        USE [msdb];
        SELECT ''MSDB_HAS_DBACCESS'', ''1'';
        SELECT ''MSDB_SYSJOBS'', CAST(ISNULL(HAS_PERMS_BY_NAME(''dbo.sysjobs'', ''OBJECT'', ''SELECT''), 0) AS VARCHAR(10));
        SELECT ''MSDB_SYSJOBSTEPS'', CAST(ISNULL(HAS_PERMS_BY_NAME(''dbo.sysjobsteps'', ''OBJECT'', ''SELECT''), 0) AS VARCHAR(10));
        SELECT ''MSDB_BACKUPSET'', CAST(ISNULL(HAS_PERMS_BY_NAME(''dbo.backupset'', ''OBJECT'', ''SELECT''), 0) AS VARCHAR(10));
        SELECT ''MSDB_SYSMAINTPLAN'', CAST(ISNULL(HAS_PERMS_BY_NAME(''dbo.sysmaintplan_plans'', ''OBJECT'', ''SELECT''), 0) AS VARCHAR(10));
        SELECT ''MSDB_LOGSHIPPING'', CAST(ISNULL(HAS_PERMS_BY_NAME(''dbo.log_shipping_primary_databases'', ''OBJECT'', ''SELECT''), 0) AS VARCHAR(10));
        SELECT ''MSDB_DATACOLLECTOR'', CAST(ISNULL(HAS_PERMS_BY_NAME(''dbo.syscollector_collection_sets'', ''OBJECT'', ''SELECT''), 0) AS VARCHAR(10));
        SELECT ''MSDB_POLICY'', CAST(ISNULL(HAS_PERMS_BY_NAME(''dbo.syspolicy_policies'', ''OBJECT'', ''SELECT''), 0) AS VARCHAR(10));
    ');
END TRY
BEGIN CATCH
    SELECT 'MSDB_HAS_DBACCESS', '0';
END CATCH;
'@
    try {
        Set-Content -Path $auditSqlPath -Encoding utf8 -Value $auditSql
        $auditCmdArgs = @('-S', $serverName, '-i', $auditSqlPath, '-d', 'master', '-C', '-l', '30', '-W', '-m', '1', '-u', '-h-1', '-w', '32768', '-s|')
        if ($sqlcmdAuthArgs -and $sqlcmdAuthArgs.Count -gt 0) {
            $auditCmdArgs += $sqlcmdAuthArgs
        }
        $rawAudit = @(sqlcmd @auditCmdArgs 2>&1)
        $auditMap = @{}
        foreach ($line in $rawAudit) {
            $str = [string]$line
            if ($str -match '^([A-Z0-9_]+)\|(.*)$') {
                $auditMap[$Matches[1].Trim()] = $Matches[2].Trim()
            }
        }

        if ($auditMap.Count -gt 0) {
            WriteLog -logLocation $foldername\$logFile -logMessage "  [PERM-AUDIT] Connected Login: $($auditMap['IDENTITY_LOGIN']) (Original: $($auditMap['IDENTITY_ORIGINAL_LOGIN']), DB User: $($auditMap['IDENTITY_USER']))" -logOperation "BOTH"
            WriteLog -logLocation $foldername\$logFile -logMessage "  [PERM-AUDIT] Server Roles: sysadmin=$($auditMap['ROLE_SYSADMIN']) securityadmin=$($auditMap['ROLE_SECURITYADMIN']) serveradmin=$($auditMap['ROLE_SERVERADMIN']) processadmin=$($auditMap['ROLE_PROCESSADMIN'])" -logOperation "BOTH"
            WriteLog -logLocation $foldername\$logFile -logMessage "  [PERM-AUDIT] Server Permissions: VIEW_SERVER_STATE=$($auditMap['PERM_VIEW_SERVER_STATE']) VIEW_ANY_DEFINITION=$($auditMap['PERM_VIEW_ANY_DEFINITION']) VIEW_ANY_DATABASE=$($auditMap['PERM_VIEW_ANY_DATABASE']) XP_READERRORLOG=$($auditMap['PERM_XP_READERRORLOG'])" -logOperation "BOTH"
            WriteLog -logLocation $foldername\$logFile -logMessage "  [PERM-AUDIT] msdb Catalog Access: HAS_DBACCESS=$($auditMap['MSDB_HAS_DBACCESS']) sysjobs=$($auditMap['MSDB_SYSJOBS']) sysjobsteps=$($auditMap['MSDB_SYSJOBSTEPS']) backupset=$($auditMap['MSDB_BACKUPSET']) sysmaintplan=$($auditMap['MSDB_SYSMAINTPLAN']) log_shipping=$($auditMap['MSDB_LOGSHIPPING']) syscollector=$($auditMap['MSDB_DATACOLLECTOR']) syspolicy=$($auditMap['MSDB_POLICY'])" -logOperation "BOTH"

            $requiredChecks = @(
                @{ Key = 'PERM_VIEW_SERVER_STATE'; Desc = 'VIEW SERVER STATE permission is missing (DMV performance, memory, CPU, waits, and encryption checks may return incomplete data).' },
                @{ Key = 'PERM_VIEW_ANY_DEFINITION'; Desc = 'VIEW ANY DEFINITION permission is missing (catalog metadata, T-SQL deep scanner, and server trigger checks may be incomplete).' },
                @{ Key = 'PERM_VIEW_ANY_DATABASE'; Desc = 'VIEW ANY DATABASE permission is missing (database enumeration may be incomplete).' },
                @{ Key = 'PERM_XP_READERRORLOG'; Desc = 'EXECUTE permission on master.dbo.xp_readerrorlog is missing (instanceErrorLog.sql will use fallback empty result).' },
                @{ Key = 'MSDB_HAS_DBACCESS'; Desc = 'Access to msdb database is missing (SQL Agent jobs, backup history, maintenance plans, and log shipping checks will be skipped).' },
                @{ Key = 'MSDB_SYSJOBS'; Desc = 'SELECT permission on msdb.dbo.sysjobs is missing (SQL Agent jobs and SSAS/subsystem detection will be incomplete).' },
                @{ Key = 'MSDB_BACKUPSET'; Desc = 'SELECT permission on msdb.dbo.backupset is missing (Transaction log backup sizing and Azure/S3 backup URL detection will be incomplete).' }
            )
            foreach ($chk in $requiredChecks) {
                if ($auditMap.ContainsKey($chk.Key) -and $auditMap[$chk.Key] -eq '0') {
                    $warnMsg = "[PERM-WARN] $($chk.Key)=0 : $($chk.Desc)"
                    $script:PermissionWarnings += $warnMsg
                    WriteLog -logLocation $foldername\$logFile -logMessage "  $warnMsg" -logOperation "BOTH"
                }
            }
        }
        else {
            WriteLog -logLocation $foldername\$logFile -logMessage "  [PERM-WARN] Pre-flight permission audit returned no structured rows." -logOperation "BOTH"
        }
    }
    catch {
        WriteLog -logLocation $foldername\$logFile -logMessage "  [PERM-WARN] Pre-flight permission audit encountered an error: $($_.Exception.Message)" -logOperation "BOTH"
    }
    finally {
        if (Test-Path -Path $auditSqlPath) {
            Remove-Item -Path $auditSqlPath -Force -ErrorAction SilentlyContinue
        }
    }
}

if ($useEntraIDAuthentication -and $useWindowsAuthentication) {
    Write-Host "-useEntraIDAuthentication and -useWindowsAuthentication are mutually exclusive." -ForegroundColor Red
    Exit 1
}

if ($useEntraIDAuthentication -and ((-not [string]::IsNullOrEmpty($collectionUserName)) -or (-not [string]::IsNullOrEmpty($collectionUserPass)))) {
    Write-Host "-collectionUserName / -collectionUserPass must not be supplied with -useEntraIDAuthentication." -ForegroundColor Red
    Write-Host "Authentication identity comes from the Microsoft Entra ID interactive MFA sign-in flow." -ForegroundColor Red
    Exit 1
}

$powerShellVersion = $PSVersionTable.PSVersion.Major
$sqlcmdCommand = Get-Command sqlcmd.exe -ErrorAction SilentlyContinue
if ($null -eq $sqlcmdCommand) {
    $sqlcmdCommand = Get-Command sqlcmd -ErrorAction SilentlyContinue
}
if ($null -eq $sqlcmdCommand) {
    Write-DmaBootstrapLog -Level "ERROR" -Message "sqlcmd is required but was not found in PATH."
    Write-Host "sqlcmd is required but was not found in PATH." -ForegroundColor Red
    Exit 1
}
$sqlcmdVersion = $sqlcmdCommand.Version
$script:NativeSqlcmdPath = $sqlcmdCommand.Source
$script:UseEntraOdbcForSqlcmd = $false
$script:DmaEntraIDUserName = $null
$script:DmaEntraOdbcConnection = $null
$foldername = ""
$totalErrorCount = 0
Write-DmaBootstrapLog -Message "Resolved sqlcmd executable: $($script:NativeSqlcmdPath) (Version: $sqlcmdVersion)"

# Pull the windows version so that we can know whether or not to skip perfmon collection or not
$windowsOSVersion = [Environment]::OSVersion.Version
$checkWindowsOSVersion = [Environment]::OSVersion.Version -ge (new-object 'Version' 6,2)

if ($ignorePerfmon -eq "true") {
    Write-Host "#############################################################"
    Write-Host "#                                                           #"
    Write-Host "#  !!!! No Windows Perfmon Data Will be Collected !!!!      #"
    Write-Host "#   A migration complexity score will be computed only ...  #"
    Write-Host "#                                                           #"
    Write-Host "#          No Right-Sizing Data will be collected           #"
    Write-Host "#                                                           #"
    Write-Host "#                                                           #"
    Write-Host "#############################################################"
    Write-Host ""
    Write-Host ""
    Write-Host ""
    $ignorePerfmonAck = Read-Host -Prompt "Acknowledge with a 'Y' to Continue"

    if ([string]::IsNullOrEmpty($ignorePerfmonAck) -or ($ignorePerfmonAck.ToUpper() -ne "Y")) {
        Write-Host "Did not Acknowldege Perfmon Warning..."
        Write-Host "Exiting Collector......."
        Exit
    }
}

if (-not $useEntraIDAuthentication) {
if ((([string]::IsNullorEmpty($collectionUserPass)) -or ([string]$collectionUserPass -eq "false")) -and (-not $useWindowsAuthentication)) {
    if ([string]($collectionUserName) -ne $(whoami)) {
        Write-Output ""
        Write-Output "Collection Username password parameter is not provided"
        $passPrompt = Read-Host 'Please enter your password' -AsSecureString
        $collectionUserPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($passPrompt))
        Set-Item -Path env:SQLCMDUSER -Value $collectionUserName
        Set-Item -Path env:SQLCMDPASSWORD -Value $collectionUserPass
        Write-Output ""
    }
    else {
        Write-Host ""
        Write-Host "#############################################################"
        Write-Host "#                                                           #"
        Write-Host "#   Executing Collection with Windows Authenticated User    #"
        Write-Host "#                                                           #"
        Write-Host "#############################################################"
        Write-Host ""
    }
}
elseif ($useWindowsAuthentication) {
    Write-Host ""
    Write-Host "#############################################################"
    Write-Host "#                                                           #"
    Write-Host "#   Executing Collection with Windows Authenticated User    #"
    Write-Host "#                                                           #"
    Write-Host "#############################################################"
    Write-Host ""
}
elseif (-not ([string]::IsNullOrEmpty($collectionUserPass))) {
    Set-Item -Path env:SQLCMDUSER -Value $collectionUserName
    Set-Item -Path env:SQLCMDPASSWORD -Value $collectionUserPass
    Write-Host ""
    Write-Host "#############################################################"
    Write-Host "#                                                           #"
    Write-Host "#     Executing Collection with SQL Authenticated User      #"
    Write-Host "#                                                           #"
    Write-Host "#############################################################"
    Write-Host ""
}
else {
    Write-Host ""
    Write-Host "#############################################################"
    Write-Host "#                                                           #"
    Write-Host "#   Executing Collection with Windows Authenticated User    #"
    Write-Host "#                                                           #"
    Write-Host "#############################################################"
    Write-Host ""
}
}

if ($useEntraIDAuthentication) {
    if ([string]::IsNullOrEmpty($entraIDUserName)) {
        Write-Host "-entraIDUserName must be supplied with -useEntraIDAuthentication." -ForegroundColor Red
        Write-Host "Example: -useEntraIDAuthentication -entraIDUserName user@domain.com" -ForegroundColor Red
        Exit 1
    }

    Remove-Item -Path env:SQLCMDUSER -ErrorAction SilentlyContinue
    Remove-Item -Path env:SQLCMDPASSWORD -ErrorAction SilentlyContinue
    Write-Host ""
    Write-Host "#############################################################"
    Write-Host "#                                                           #"
    Write-Host "#    Executing Collection with Entra ID Authentication      #"
    Write-Host "#                                                           #"
    Write-Host "#############################################################"
    Write-Host "    No collection username or password will be passed."
    Write-Host "    Entra ID sign-in user: $entraIDUserName"
    Write-Host "    sqlcmd path: $($sqlcmdCommand.Source)"
    Write-Host "    sqlcmd version: $sqlcmdVersion"
    Write-Host "    Entra ID collection will use one persistent ODBC connection."
    Write-Host ""
    $script:DmaEntraIDUserName = $entraIDUserName
    $script:UseEntraOdbcForSqlcmd = $true
    $sqlcmdAuthArgs = @()
} else {
    $sqlcmdAuthArgs = @()
}

if (-not $useEntraIDAuthentication) {
$requiredVersion = "11.0.7512.0"
if ($sqlcmdVersion -lt $requiredVersion) {
    Write-Host "#############################################################"
    Write-Host "#                                                           #"
    Write-Host "#       !!!! The installed version of SQL CMD is !!!!       #"
    Write-Host "#              lower than the required version              #"
    Write-Host "#                                                           #"
    Write-Host "#          Supported Versions ODBC >= $requiredVersion      #"
    Write-Host "#               Collection Errors may Occur                 #"
    Write-Host "#                                                           #"
    Write-Host "#                                                           #"
    Write-Host "#############################################################"
    Write-Host ""
    Write-Host ""
    Write-Host ""
    $versionAck = Read-Host -Prompt "Acknowledge with a 'Y' to Continue"

    if ($versionAck.ToUpper() -ne "Y") {
        Write-Host "Did not Acknowldege SQL CMD Version Warning..."
        Write-Host "Exiting Collector......."
        Exit
    }
}
}

if ($(Get-Location).Path -ne $PSScriptRoot) {
    $currentTimestamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    Write-Host "$currentTimestamp   Script Location: $PSScriptRoot"
    $currentTimestamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    Write-Host "$currentTimestamp   Running script from directory: $(Get-Location)"
	$originalLocation = $(Get-Location).Path
	Push-Location -Path $PSScriptRoot
    $currentTimestamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    Write-Host "$currentTimestamp   Changing Directory for script execution to $PSScriptRoot ....."
}

if ([string]::IsNullorEmpty($serverName)) {
    Write-DmaBootstrapLog -Level "ERROR" -Message "Server parameter serverName is empty."
    Write-Output "Server parameter $serverName is empty.  Ensure that the parameter is provided"
    Exit 1
}
elseif ([string]::IsNullorEmpty($collectionUserName) -and (-not $useWindowsAuthentication) -and (-not $useEntraIDAuthentication)) {
    Write-DmaBootstrapLog -Level "ERROR" -Message "Collection Username parameter collectionUserName is empty without -useWindowsAuthentication or -useEntraIDAuthentication."
    Write-Output "Collection Username parameter $collectionUserName is empty."
    Write-Output "Ensure that the parameter is provided or -useWindowsAuthentication is specified"
    Exit 1
}
elseif (((checkStringForSpecialChars -inputString $manualUniqueId) -eq "fail") -and (![string]::IsNullorEmpty($manualUniqueId))) {
    Write-DmaBootstrapLog -Level "ERROR" -Message "Manual Unique Id parameter '$manualUniqueId' contains invalid characters."
    Write-Output "Manual Unique Id parameter $manualUniqueId contains spaces or special characters.  Ensure that the parameter contains only letters, numbers and no spaces"
    Exit 1
}
else {
    ### Surround the databaseName variable with quotes to protect from values that have spaces in it
    $databaseNameFilter = '"{0}"' -f $database
    $inputServerName = $serverName
    if ((-not [string]::IsNullorEmpty($port)) -and ($port -ne "default")) {
        $serverName = "$serverName,$port"
    }
    WriteLog -logMessage "Retrieving Metadata Information from $serverName" -logOperation "MESSAGE"
    Write-DmaBootstrapLog -Message "Connecting to SQL Server '$serverName' to retrieve initial metadata (sql\foldername.sql)..."
    $rawFolderOut = @(sqlcmd -S $serverName -i sql\foldername.sql -d master -C -l 30 -W -m 1 -u -w 32768 -v database=$databaseNameFilter @sqlcmdAuthArgs 2>&1)
    $folderExitCode = $LASTEXITCODE
    $folderObj = @($rawFolderOut | ForEach-Object { [string]$_ } | findstr /v /c:"---")
    Write-DmaBootstrapLog -Message "sql\foldername.sql completed (ExitCode=$folderExitCode, Lines=$($rawFolderOut.Count)): $($rawFolderOut -join ' | ')"

    $bootstrapConnectionFailed = $false
    if ([string]::IsNullorEmpty($folderObj) -or ($folderObj.Count -lt 2)) {
        $bootstrapConnectionFailed = $true
    }
    elseif (($rawFolderOut -join "`n") -match '(Sqlcmd:\s*Error:|Msg\s+\d+,\s*Level\s+\d+,\s*State\s+\d+|Login failed for user|HResult\s+0x)') {
        $bootstrapConnectionFailed = $true
    }

    if (-not $bootstrapConnectionFailed) {
        $splitobj = $folderObj[1].Split('')
        $values = @($splitobj | ForEach-Object { if ($_.Trim() -ne '') { $_ } })
        if ($values.Count -lt 6) {
            $bootstrapConnectionFailed = $true
        }
    }

    if ($bootstrapConnectionFailed) {
        $errDetail = ($rawFolderOut | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
        Write-DmaBootstrapLog -Level "ERROR" -Message "Connection/Metadata query to SQL Server '$serverName' failed:`n$errDetail"
        Write-Output " "
        Write-Output "Connection Error to SQL Server $serverName.  Exiting Script...."
        if (-not [string]::IsNullOrWhiteSpace($errDetail)) {
            Write-Host "SQLCMD Output / Error Details:" -ForegroundColor Red
            Write-Host $errDetail -ForegroundColor Red
            Write-Host "Bootstrap diagnostic log written to: $script:BootstrapLogFile" -ForegroundColor Yellow
        }
        Exit 1
    }

    $validSQLInstanceVersionCheckArray = @(sqlcmd -S $serverName -i sql\checkValidInstanceVersion.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 @sqlcmdAuthArgs)
    Write-DmaBootstrapLog -Message "sql\checkValidInstanceVersion.sql returned: $($validSQLInstanceVersionCheckArray -join ' | ')"
    $dbNameArray = @(sqlcmd -S $serverName -i sql\getDBList.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 -v database=$databaseNameFilter -v hasdbaccess=1 @sqlcmdAuthArgs)
    Write-DmaBootstrapLog -Message "sql\getDBList.sql (hasdbaccess=1) returned $($dbNameArray.Count) accessible database(s): $($dbNameArray -join ', ')"
    $dbNameNoAccessArray = @(sqlcmd -S $serverName -i sql\getDBList.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 -v database=$databaseNameFilter -v hasdbaccess=0 @sqlcmdAuthArgs)
    Write-DmaBootstrapLog -Message "sql\getDBList.sql (hasdbaccess=0) returned $($dbNameNoAccessArray.Count) inaccessible database(s): $($dbNameNoAccessArray -join ', ')"
    $dmaSourceIdObj = @(sqlcmd -S $serverName -i sql\getDmaSourceId.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 @sqlcmdAuthArgs)
    Write-DmaBootstrapLog -Message "sql\getDmaSourceId.sql returned: $($dmaSourceIdObj -join ' | ')"

    if ([string]$database -ne "all") {
        $validDBObj = sqlcmd -S $serverName -i sql\checkValidDatabase.sql -C -l 30 -W -m 1 -u -h-1 -w 32768 -v database=$databaseNameFilter @sqlcmdAuthArgs | findstr /v /c:"-"
        if (([string]::IsNullorEmpty($folderObj)) -or ([int]$validDBObj -eq 0)) {
            Write-DmaBootstrapLog -Level "ERROR" -Message "SQL Server Database '$database' not valid or inaccessible on $serverName."
            Write-Output " "
            Write-Output "SQL Server Database $database not valid.  Exiting Script...."
            Exit 1
        }
    }
}

$dbversion = $values[0].Replace('.', '')
$machinename = $values[1]
if ($machinename.Contains('.')) {
    $machinename = $machinename.Split('.')[0]
}
if ([string]$database -eq "all") {
    $dbname = $values[2] -replace '\s', ''
}
else {
    $dbname = $database -replace '\s', ''
}
$instancename = $values[3]
$current_ts = $values[4]
$pkey = $values[5]
$dmaSourceId = $dmaSourceIdObj[0]

$splitValidInstanceVerisionCheckObj = $validSQLInstanceVersionCheckArray[0].Split('')
$validSQLInstanceVersionCheckValues = $splitValidInstanceVerisionCheckObj | ForEach-Object { if ($_.Trim() -ne '') { $_ } }
$isValidSQLInstanceVersion = $validSQLInstanceVersionCheckValues[0]
$isCloudOrLinuxHost = $validSQLInstanceVersionCheckValues[1]

$op_version = "4.3.48"

if ([string]($isValidSQLInstanceVersion) -eq "N") {
    Write-Host "#############################################################"
    Write-Host "#                                                           #"
    Write-Host "#          !!!! Collector has not been tested !!!!          #"
    Write-Host "#              with this version of SQL Server              #"
    Write-Host "#                                                           #"
    Write-Host "#          Supported Versions are 2008R2 thru 2022          #"
    Write-Host "#               Collection Errors may Occur                 #"
    Write-Host "#                                                           #"
    Write-Host "#                                                           #"
    Write-Host "#############################################################"
    Write-Host ""
    Write-Host ""
    Write-Host ""
    $versionAck = Read-Host -Prompt "Acknowledge with a 'Y' to Continue"

    if ($versionAck.ToUpper() -ne "Y") {
        Write-Host "Did not Acknowldege Version Warning..."
        Write-Host "Exiting Collector......."
        Exit
    }
}

# Ignore and create empty perfmon if flag is set or Windows version is not > Server 2008.  Otherwise set flags
# so that perfmon is processed as directed
if ($ignorePerfmon -eq "true") {
    $perfCounterLabel = "NoPerfCounter"
} elseif ($checkWindowsOSVersion -eq $false) {
    $perfCounterLabel = "NoPerfCounter"
    $ignorePerfmon = "true"
    $ignorePerfmonOsIncompatible = $true
}
else {
    $perfCounterLabel = "PerfCounter"
}

$foldername = 'opdb' + '_' + 'mssql' + '_' + $perfCounterLabel + '__' + $dbversion + '_' + $op_version + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts
$logFile = 'opdb_mssql_collectorLog' + '__' + $dbversion + '_' + $op_version + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.log'
$sqlErrorLogFile = 'opdb_mssql_sqlErrorlog' + '__' + $dbversion + '_' + $op_version + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.log'

$folderLength = ($PSScriptRoot + '\' + $foldername).Length

# Check to see if registry allows long paths > 260 chars only valid for certain operating systems
$LongPathsEnabledValue = $(Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "LongPathsEnabled")
if ($null -eq $LongPathsEnabledValue) {
    $LongPathsEnabledValue = 0
}

# Check only the folder length to see if it exceeds 260 Chars when LongPathsEnabled equals 0 (not enabled)
if (($folderLength -le 260 -and $LongPathsEnabledValue -eq 0) -or ($folderLength -le 260 -and $LongPathsEnabledValue -eq 1) -or ($folderLength -ge 260 -and $LongPathsEnabledValue -eq 1)) {
    WriteLog -logMessage "Creating directory $PSScriptRoot\$foldername" -logOperation "MESSAGE"
    Write-Output " "
    $null = New-Item -Name $foldername -ItemType Directory
}
else {
    if ($folderLength -gt 260 -and $LongPathsEnabledValue -eq 0) {
        WriteLog -logMessage "Folder length exceeds 260 characters.  Run collection tool from a path with less characters" -logOperation "MESSAGE"
        WriteLog -logMessage "Folder being created is: $PSScriptRoot\$foldername" -logOperation "MESSAGE"
        Write-Output " "
        Write-Host "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) Consider shortening foldername by reducing 'db-migration-assessment-collection-scripts-sqlserver' to 'google-dma'" -ForegroundColor red
        Write-Host "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) Or Consider setting registry value 'LongPathsEnabled' to '1'" -ForegroundColor red
        Write-Host "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) See 'https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation?tabs=powershell' for more information" -ForegroundColor red
        Exit 1
    }
}

# Complete test to ensure that the folder got created.  Fail with error message if it did not
if (Test-Path -Path $PSScriptRoot\$foldername) {
    WriteLog -logMessage "  Directory $PSScriptRoot\$foldername successfully created" -logOperation "MESSAGE"
    Write-Output " "
}
else {
    Write-Host "Output folder $PSScriptRoot\$foldername was not created."  -ForegroundColor red
    Write-Host "Exiting Script"  -ForegroundColor red
    Exit 1
}

$logFileArray = @($logFile, $sqlErrorLogFile)

# Check all the log files to make sure they fit in the 260 char limit when LongPathsEnabled equals 0 (not enabled)
WriteLog -logMessage "Checking directory path + log file name lengths for max length limitations..." -logOperation "MESSAGE"
foreach ($logFileName in $logFileArray) {
    $folderLength = ($PSScriptRoot + '\' + $foldername + '\' + $logFileName).Length
    if ($folderLength -gt 260 -and $LongPathsEnabledValue -eq 0) {
        WriteLog -logMessage "Output file $PSScriptRoot\$foldername\$logFileName name exceeds 260 characters." -logOperation "MESSAGE"
        Write-Output " "
        Write-Host "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) Execute collection from a path with less than 260 characters." -ForegroundColor red
        Write-Host "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) Consider shortening foldername by reducing 'db-migration-assessment-collection-scripts-sqlserver' to 'google-dma'" -ForegroundColor red
        Write-Host "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) Or Consider setting registry value 'LongPathsEnabled' to '1'" -ForegroundColor red
        Write-Host "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) See 'https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation?tabs=powershell' for more information" -ForegroundColor red
        Exit 1
    }
}

if (Test-Path -Path $script:BootstrapLogFile) {
    Get-Content -Path $script:BootstrapLogFile | Add-Content -Encoding utf8 -Path $foldername\$logFile
    Add-Content -Encoding utf8 -Path $foldername\$logFile -Value ""
}

WriteLog -logLocation $foldername\$logFile -logMessage "PS Version Table" -logOperation "FILE"
$PSVersionTable | out-string | Add-Content -Encoding utf8 -Path $foldername\$logFile

WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "Windows OS Version" -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "$windowsOSVersion" -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "Custom Output Directory: " $outputDirectory

if ($ignorePerfmonOsIncompatible -eq $true) {
    WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "FILE"
    WriteLog -logLocation $foldername\$logFile -logMessage "Skipping Perfmon Collection Due to OS Incompatibility" -logOperation "FILE"
}

WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "Registry Value for Long Paths" -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem\LongPathsEnabled = $LongPathsEnabledValue" -logOperation "FILE"

WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "SQLCMD Version Table" -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage $sqlcmdVersion -logOperation "FILE"

WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "Output Encoding Table" -logOperation "FILE"
$OutputEncoding | out-string | Add-Content -Encoding utf8 -Path $foldername\$logFile

if ([string]::IsNullorEmpty($dmaSourceId)) {
    WriteLog -logLocation $foldername\$logFile -logMessage "Derived parameter DMASourceID is not populated.  Defaulting value...." -logOperation "BOTH"
    WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "BOTH"
    $dmaSourceId = 'NotPopulated'
}
else {
    WriteLog -logLocation $foldername\$logFile -logMessage "DMA Source Id: $dmaSourceId " -logOperation "FILE"
    WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "FILE"
}

WriteLog -logLocation $foldername\$logFile -logMessage "DMA Manual Id: $manualUniqueId " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "FILE"

WriteLog -logLocation $foldername\$logFile -logMessage "SQL Server Version: $dbversion " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "FILE"

WriteLog -logLocation $foldername\$logFile -logMessage "Execution Variables List" -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "serverName = $inputServerName " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "port = $port " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "database = $databaseNameFilter " -logOperation "FILE"
if ($useWindowsAuthentication) {
    WriteLog -logLocation $foldername\$logFile -logMessage "collectionUserName = $(whoami) " -logOperation "FILE"
}
elseif ($useEntraIDAuthentication) {
    WriteLog -logLocation $foldername\$logFile -logMessage "collectionUserName = Microsoft Entra ID interactive authentication" -logOperation "FILE"
}
else {
    WriteLog -logLocation $foldername\$logFile -logMessage "collectionUserName = $collectionUserName " -logOperation "FILE"
}

WriteLog -logLocation $foldername\$logFile -logMessage "ignorePerfmon = $ignorePerfmon " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "connectionString = $serverName " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "FILE"

$outputFileSuffix = '__' + $dbversion + '_' + $op_version + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'

$compFileName = 'opdb' + '__' + 'CompInstalled' + $outputFileSuffix
$srvFileName = 'opdb' + '__' + 'ServerProps' + $outputFileSuffix
$blockingFeatures = 'opdb' + '__' + 'BlockFeatures' + $outputFileSuffix
$linkedServers = 'opdb' + '__' + 'LinkedSrvrs' + $outputFileSuffix
$dbsizes = 'opdb' + '__' + 'DbSizes' + $outputFileSuffix
$dbClusterNodes = 'opdb' + '__' + 'DbClusterNodes' + $outputFileSuffix
$objectList = 'opdb' + '__' + 'ObjectList' + $outputFileSuffix
$tableList = 'opdb' + '__' + 'TableList' + $outputFileSuffix
$indexList = 'opdb' + '__' + 'IndexList' + $outputFileSuffix
$columnDatatypes = 'opdb' + '__' + 'ColumnDatatypes' + $outputFileSuffix
$userConnectionList = 'opdb' + '__' + 'UserConnections' + $outputFileSuffix
$perfMonOutput = 'opdb' + '__' + 'PerfMonData' + $outputFileSuffix
$dbccTraceFlg = 'opdb' + '__' + 'DbccTrace' + $outputFileSuffix
$diskVolumeInfo = 'opdb' + '__' + 'DiskVolInfo' + $outputFileSuffix
$dbServerFlags = 'opdb' + '__' + 'DbServerFlags' + $outputFileSuffix
$dbServerConfig = 'opdb' + '__' + 'DbServerConfig' + $outputFileSuffix
$dbServerDmvPerfmon = 'opdb' + '__' + 'DmvPerfmon' + $outputFileSuffix
$manifestFile = 'opdb' + '__' + 'manifest' + $outputFileSuffix
$computerSpecsFile = 'opdb' + '__' + 'DbMachineSpecs' + $outputFileSuffix
$sqlAgentJobs = 'opdb' + '__' + 'SqlAgentJobs' + $outputFileSuffix
$tranLogBkupCountByDayByHour = 'opdb' + '__' + 'TranLogBkupCountByHourByDay' + $outputFileSuffix
$tranLogBkupSizeByDayByHour = 'opdb' + '__' + 'TranLogBkupSizeByHourByDay' + $outputFileSuffix
$databaseLevelBlockingFeatures = 'opdb' + '__' + 'DatabaseLevelBlockFeatures' + $outputFileSuffix
$cpuUsageFileName = 'opdb' + '__' + 'CpuUsage' + $outputFileSuffix
$memoryUsageFileName = 'opdb' + '__' + 'MemoryUsage' + $outputFileSuffix
$memorySizingFileName = 'opdb' + '__' + 'MemorySizing' + $outputFileSuffix
$memoryClerksFileName = 'opdb' + '__' + 'MemoryClerks' + $outputFileSuffix
$batchFootprintFileName = 'opdb' + '__' + 'BatchFootprint' + $outputFileSuffix
$waitsStats = 'opdb' + '__' + 'WaitsStats' + $outputFileSuffix
$queryOptimizerInfo = 'opdb' + '__' + 'QueryOptimizerInfo' + $outputFileSuffix
$fileIoLatency = 'opdb' + '__' + 'FileIoLatency' + $outputFileSuffix
$instanceErrorLog = 'opdb' + '__' + 'InstanceErrorLog' + $outputFileSuffix
$deprecatedFeatures = 'opdb' + '__' + 'DeprecatedFeatures' + $outputFileSuffix
$deepScanner = 'opdb' + '__' + 'PostgresMigrationIssues' + $outputFileSuffix

$outputFileArray = @($compFileName,
    $srvFileName,
    $blockingFeatures,
    $linkedServers,
    $dbsizes,
    $dbClusterNodes,
    $objectList,
    $tableList,
    $indexList,
    $columnDatatypes,
    $userConnectionList,
    $perfMonOutput,
    $dbccTraceFlg,
    $diskVolumeInfo,
    $dbServerFlags,
    $dbServerConfig,
    $dbServerDmvPerfmon,
    $manifestFile,
    $computerSpecsFile,
    $sqlAgentJobs,
    $tranLogBkupCountByDayByHour,
    $tranLogBkupSizeByDayByHour,
    $databaseLevelBlockingFeatures,
    $cpuUsageFileName,
    $memoryUsageFileName,
    $memorySizingFileName,
    $memoryClerksFileName,
    $batchFootprintFileName,
    $waitsStats,
    $queryOptimizerInfo,
    $fileIoLatency,
    $instanceErrorLog,
    $deprecatedFeatures,
    $deepScanner)

# Check individual folder + file names for max length
WriteLog -logMessage "Checking directory path + output file name lengths for max length limitations..." -logOperation "MESSAGE"
foreach ($directory in $outputFileArray) {
    $folderLength = ($PSScriptRoot + '\' + $foldername + '\' + $directory).Length
    if ($folderLength -gt 260 -and $LongPathsEnabledValue -eq 0) {
        WriteLog -logMessage "Output file $PSScriptRoot\$foldername\$directory name exceeds 260 characters." -logOperation "MESSAGE"
        Write-Output " "
        WriteLog -logMessage "Execute collection from a path with less than 260 characters." -logOperation "MESSAGE"
        Write-Host "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) Execute collection from a path with less than 260 characters." -ForegroundColor red
        Write-Host "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) Consider shortening foldername by reducing 'db-migration-assessment-collection-scripts-sqlserver' to 'google-dma'" -ForegroundColor red
        Write-Host "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) Or Consider setting registry value 'LongPathsEnabled' to '1'" -ForegroundColor red
        Write-Host "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) See 'https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation?tabs=powershell' for more information" -ForegroundColor red
        Exit 1
    }
}

### Just write the names of the databases that the collector will act upon to the screen and the log file
WriteLog -logLocation $foldername\$logFile -logMessage "Executing Assessment on Server $serverName Against the Following Databases:" -logOperation "BOTH"
foreach ($dbNameList in $dbNameArray) {
    WriteLog -logLocation $foldername\$logFile -logMessage "            $dbNameList" -logOperation "BOTH"
}

### Just write the names of the databases that the collector will skip due to permissions issues to the screen and the log file
if ($dbNameNoAccessArray.Count -gt 0) {
    WriteLog -logLocation $foldername\$logFile -logMessage "Skipping Databases Due to Permissions Issues:" -logOperation "BOTH"
    foreach ($dbNameNoAccessList in $dbNameNoAccessArray) {
        WriteLog -logLocation $foldername\$logFile -logMessage "            $dbNameNoAccessList" -logOperation "BOTH"
    }
}

Invoke-DmaPermissionAudit

$stdSqlVars = @("pkey=$pkey", "dmaSourceId=$dmaSourceId", "dmaManualId=$manualUniqueId")

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Installed Components..." -logOperation "BOTH"
Set-Content -Path $foldername\$compFileName -Encoding utf8 -Value '"PKEY"|"physical_server_name"|"sql_instance_name"|"sql_server_services"|"current_service_status"|"status_date_time"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "ComponentsInstalled" -SqlFile "sql\componentsInstalled.sql" -DatabaseName "master" -OutputFilePath "$foldername\$compFileName" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Properties..." -logOperation "BOTH"
Set-Content -Path $foldername\$srvFileName -Encoding utf8 -Value '"PKEY"|"property_name"|"property_value"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "ServerProperties" -SqlFile "sql\serverProperties.sql" -DatabaseName "master" -OutputFilePath "$foldername\$srvFileName" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server CloudSQL Unsupported Flag Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$dbServerFlags -Encoding utf8 -Value '"PKEY"|"flag_name"|"value"|"value_in_use"|"description"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "DbServerUnsupportedFlags" -SqlFile "sql\dbServerUnsupportedFlags.sql" -DatabaseName "master" -OutputFilePath "$foldername\$dbServerFlags" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Blocked Features in Use..." -logOperation "BOTH"
Set-Content -Path $foldername\$blockingFeatures -Encoding utf8 -Value '"PKEY"|"Features"|"Is_EnabledOrUsed"|"Count"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "DbServerFeatures" -SqlFile "sql\dbServerFeatures.sql" -DatabaseName "master" -OutputFilePath "$foldername\$blockingFeatures" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Linked Server Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$linkedServers -Encoding utf8 -Value '"pkey"|"name"|"product"|"provider"|"data_source"|"location"|"provider_string"|"catalog"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "LinkedServersDetail" -SqlFile "sql\linkedServersDetail.sql" -DatabaseName "master" -OutputFilePath "$foldername\$linkedServers" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Cluster Node Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$dbClusterNodes -Encoding utf8 -Value '"pkey"|"node_name"|"status"|"status_description"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "DbClusterNodes" -SqlFile "sql\dbClusterNodes.sql" -DatabaseName "master" -OutputFilePath "$foldername\$dbClusterNodes" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server DBCC Trace Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$dbccTraceFlg -Encoding utf8 -Value '"PKEY"|"name"|"status"|"global"|"session"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "DbccTraceFlags" -SqlFile "sql\dbccTraceFlags.sql" -DatabaseName "master" -OutputFilePath "$foldername\$dbccTraceFlg" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server CPU Usage Info (Ring Buffer)..." -logOperation "BOTH"
Set-Content -Path $foldername\$cpuUsageFileName -Encoding utf8 -Value '"PKEY"|"timestamp"|"process_utilization"|"system_idle"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "CpuUsage" -SqlFile "sql\cpuUsage.sql" -DatabaseName "master" -OutputFilePath "$foldername\$cpuUsageFileName" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Memory Usage Info (Ring Buffer)..." -logOperation "BOTH"
Set-Content -Path $foldername\$memoryUsageFileName -Encoding utf8 -Value '"PKEY"|"timestamp"|"state"|"available_physical_memory_mb"|"working_set_mb"|"percent_committed_in_ws"|"system_physical_memory_high"|"system_physical_memory_low"|"process_physical_memory_low"|"process_virtual_memory_low"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "MemoryUsage" -SqlFile "sql\memoryUsage.sql" -DatabaseName "master" -OutputFilePath "$foldername\$memoryUsageFileName" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Memory Sizing Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$memorySizingFileName -Encoding utf8 -Value '"PKEY"|"host_ram_mb"|"available_host_ram_mb"|"max_server_memory_mb"|"min_server_memory_mb"|"sql_working_set_mb"|"memory_model"|"user_data_on_disk_mb"|"buffer_pool_user_data_mb"|"lifetime_pressure_events"|"internal_sql_pressure_events"|"external_os_pressure_events"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "MemorySizing" -SqlFile "sql\memorySizing.sql" -DatabaseName "master" -OutputFilePath "$foldername\$memorySizingFileName" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Memory Clerks Breakdown..." -logOperation "BOTH"
Set-Content -Path $foldername\$memoryClerksFileName -Encoding utf8 -Value '"PKEY"|"memory_clerk_type"|"allocated_mb"|"pct_of_total_sql_memory"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "MemoryClerks" -SqlFile "sql\memoryClerks.sql" -DatabaseName "master" -OutputFilePath "$foldername\$memoryClerksFileName" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Batch Footprint Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$batchFootprintFileName -Encoding utf8 -Value '"PKEY"|"AvgRunTimeMS"|"StatementCount"|"counter_name"|"TotalElapsedTimeMS"|"ExecutionTimePercent"|"ExecutionCountPercent"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "BatchFootprint" -SqlFile "sql\batchFootprint.sql" -DatabaseName "master" -OutputFilePath "$foldername\$batchFootprintFileName" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Waits Stats Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$waitsStats -Encoding utf8 -Value '"PKEY"|"WaitType"|"Wait_S"|"Resource_S"|"Signal_S"|"WaitCount"|"Percentage"|"AvgWait_S"|"AvgRes_S"|"AvgSig_S"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "WaitsStats" -SqlFile "sql\waitsStats.sql" -DatabaseName "master" -OutputFilePath "$foldername\$waitsStats" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Query Optimizer Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$queryOptimizerInfo -Encoding utf8 -Value '"PKEY"|"counter"|"value"|"occurrence"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "QueryOptimizerInfo" -SqlFile "sql\queryOptimizerInfo.sql" -DatabaseName "master" -OutputFilePath "$foldername\$queryOptimizerInfo" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server File IO Latency Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$fileIoLatency -Encoding utf8 -Value '"PKEY"|"DatabaseName"|"LogicalFileName"|"FileType"|"PhysicalPath"|"TotalReads"|"DataReadMB"|"TotalReadStallMs"|"AvgReadLatencyMs"|"TotalWrites"|"DataWrittenMB"|"TotalWriteStallMs"|"AvgWriteLatencyMs"|"TotalIOStallMs"|"SizeOnDiskMB"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "FileIoLatency" -SqlFile "sql\fileIoLatency.sql" -DatabaseName "master" -OutputFilePath "$foldername\$fileIoLatency" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Instance Error Log Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$instanceErrorLog -Encoding utf8 -Value '"PKEY"|"timestamp"|"process_info"|"log_message"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "InstanceErrorLog" -SqlFile "sql\instanceErrorLog.sql" -DatabaseName "master" -OutputFilePath "$foldername\$instanceErrorLog" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Deprecated Features Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$deprecatedFeatures -Encoding utf8 -Value '"PKEY"|"FeatureName"|"UsageCount"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "DeprecatedFeatures" -SqlFile "sql\deprecatedFeatures.sql" -DatabaseName "master" -OutputFilePath "$foldername\$deprecatedFeatures" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Disk Volume Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$diskVolumeInfo -Encoding utf8 -Value '"PKEY"|"volume_mount_point"|"file_system_type"|"logical_volume_name"|"total_size_gb"|"available_size_gb"|"space_free_pct"|"cluster_block_size"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "DiskVolumeInfo" -SqlFile "sql\diskVolumeInfo.sql" -DatabaseName "master" -OutputFilePath "$foldername\$diskVolumeInfo" -SqlcmdVars $stdSqlVars

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Configuration Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$dbServerConfig -Encoding utf8 -Value '"pkey"|"configuration_id"|"name"|"value"|"minimum"|"maximum"|"value_in_use"|"description"|"dma_source_id"|"dma_manual_id"'
Invoke-DmaSqlStep -StepName "DbServerConfigurationSettings" -SqlFile "sql\dbServerConfigurationSettings.sql" -DatabaseName "master" -OutputFilePath "$foldername\$dbServerConfig" -SqlcmdVars $stdSqlVars

if ($isCloudOrLinuxHost -eq "AZURE") {
    WriteLog -logLocation $foldername\$logFile -logMessage "Skipping SQL Server Transaction Log Backup Info...Unavailable in AZURE SQL Managed Instance." -logOperation "BOTH"
    Set-Content -Path $foldername\$tranLogBkupCountByDayByHour -Encoding utf8 -Value '"PKEY"|"collection_date"|"day_of_month"|"total_logs_generated"|"h0_count"|"h1_count"|"h2_count"|"h3_count"|"h4_count"|"h5_count"|"h6_count"|"h7_count"|"h8_count"|"h9_count"|"h10_count"|"h11_count"|"h12_count"|"h13_count"|"h14_count"|"h15_count"|"h16_count"|"h17_count"|"h18_count"|"h19_count"|"h20_count"|"h21_count"|"h22_count"|"h23_count"|"avg_per_hour"|"dma_source_id"|"dma_manual_id"'
    WriteLog -logLocation $foldername\$logFile -logMessage "     Writing Empty $tranLogBkupCountByDayByHour File" -logOperation "BOTH"
    Set-Content -Path $foldername\$tranLogBkupSizeByDayByHour -Encoding utf8 -Value '"PKEY"|"collection_date"|"day_of_month"|"total_logs_generated_in_mb"|"h0_size_in_mb"|"h1_size_in_mb"|"h2_size_in_mb"|"h3_size_in_mb"|"h4_size_in_mb"|"h5_size_in_mb"|"h6_size_in_mb"|"h7_size_in_mb"|"h8_size_in_mb"|"h9_size_in_mb"|"h10_size_in_mb"|"h11_size_in_mb"|"h12_size_in_mb"|"h13_size_in_mb"|"h14_size_in_mb"|"h15_size_in_mb"|"h16_size_in_mb"|"h17_size_in_mb"|"h18_size_in_mb"|"h19_size_in_mb"|"h20_size_in_mb"|"h21_size_in_mb"|"h22_size_in_mb"|"h23_size_in_mb"|"avg_mb_per_hour"|"dma_source_id"|"dma_manual_id"'
    WriteLog -logLocation $foldername\$logFile -logMessage "     Writing Empty $tranLogBkupSizeByDayByHour File" -logOperation "BOTH"
}
else {
    WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Transaction Log Backup Info..." -logOperation "BOTH"
    Set-Content -Path $foldername\$tranLogBkupCountByDayByHour -Encoding utf8 -Value '"PKEY"|"collection_date"|"day_of_month"|"total_logs_generated"|"h0_count"|"h1_count"|"h2_count"|"h3_count"|"h4_count"|"h5_count"|"h6_count"|"h7_count"|"h8_count"|"h9_count"|"h10_count"|"h11_count"|"h12_count"|"h13_count"|"h14_count"|"h15_count"|"h16_count"|"h17_count"|"h18_count"|"h19_count"|"h20_count"|"h21_count"|"h22_count"|"h23_count"|"avg_per_hour"|"dma_source_id"|"dma_manual_id"'
    Set-Content -Path $foldername\$tranLogBkupSizeByDayByHour -Encoding utf8 -Value '"PKEY"|"collection_date"|"day_of_month"|"total_logs_generated_in_mb"|"h0_size_in_mb"|"h1_size_in_mb"|"h2_size_in_mb"|"h3_size_in_mb"|"h4_size_in_mb"|"h5_size_in_mb"|"h6_size_in_mb"|"h7_size_in_mb"|"h8_size_in_mb"|"h9_size_in_mb"|"h10_size_in_mb"|"h11_size_in_mb"|"h12_size_in_mb"|"h13_size_in_mb"|"h14_size_in_mb"|"h15_size_in_mb"|"h16_size_in_mb"|"h17_size_in_mb"|"h18_size_in_mb"|"h19_size_in_mb"|"h20_size_in_mb"|"h21_size_in_mb"|"h22_size_in_mb"|"h23_size_in_mb"|"avg_mb_per_hour"|"dma_source_id"|"dma_manual_id"'
    Invoke-DmaSqlStep -StepName "TranLogBackupCountByHourByDay" -SqlFile "sql\dbServerTranLogBackupCountByDayByHour.sql" -DatabaseName "msdb" -OutputFilePath "$foldername\$tranLogBkupCountByDayByHour" -SqlcmdVars $stdSqlVars
    Invoke-DmaSqlStep -StepName "TranLogBackupSizeByHourByDay" -SqlFile "sql\dbServerTranLogBackupSizeByDayByHour.sql" -DatabaseName "msdb" -OutputFilePath "$foldername\$tranLogBkupSizeByDayByHour" -SqlcmdVars $stdSqlVars
}

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Agent Jobs Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$sqlAgentJobs -Encoding utf8 -Value '"pkey"|"dma_source_id"|"dma_manual_id"|"job_id"|"job_name"|"job_enabled"|"category_name"|"job_description"|"step_id"|"step_name"|"subsystem"|"command"|"database_name"|"incompatibility_category"|"incompatibility_type"|"severity"'
Invoke-DmaSqlStep -StepName "SqlAgentJobs" -SqlFile "sql\sqlAgentJobs.sql" -DatabaseName "msdb" -OutputFilePath "$foldername\$sqlAgentJobs" -SqlcmdVars $stdSqlVars

### First establish headers for the collection files which could execute against multiple databases in the instance
Set-Content -Path $foldername\$objectList -Encoding utf8 -Value '"PKEY"|"database_name"|"schema_name"|"object_name"|"object_type"|"object_type_desc"|"object_count"|"lines_of_code"|"associated_table_name"|"dma_source_id"|"dma_manual_id"'
Set-Content -Path $foldername\$tableList -Encoding utf8 -Value '"PKEY"|"database_name"|"schema_name"|"table_name"|"partition_count"|"is_memory_optimized"|"temporal_type"|"is_external"|"lock_escalation"|"is_tracked_by_cdc"|"text_in_row_limit"|"is_replicated"|"row_count"|"data_compression"|"total_space_mb"|"used_space_mb"|"unused_space_mb"|"dma_source_id"|"dma_manual_id"|"partition_type"|"is_temp_table"'
Set-Content -Path $foldername\$indexList -Encoding utf8 -Value '"PKEY"|"database_name"|"schema_name"|"table_name"|"index_name"|"index_type"|"is_primary_key"|"is_unique"|"fill_factor"|"allow_page_locks"|"has_filter"|"data_compression"|"data_compression_desc"|"is_partitioned"|"count_key_ordinal"|"count_partition_ordinal"|"count_is_included_column"|"total_space_mb"|"dma_source_id"|"dma_manual_id"|"is_computed_index"|"is_index_on_view"'
Set-Content -Path $foldername\$columnDatatypes -Encoding utf8 -Value '"PKEY"|"database_name"|"schema_name"|"table_name"|"datatype"|"max_length"|"precision"|"scale"|"is_computed"|"is_filestream"|"is_masked"|"encryption_type"|"is_sparse"|"rule_object_id"|"column_count"|"dma_source_id"|"dma_manual_id"'
Set-Content -Path $foldername\$userConnectionList -Encoding utf8 -Value '"PKEY"|"database_name"|"is_user_process"|"host_name"|"program_name"|"login_name"|"num_reads"|"num_writes"|"last_read"|"last_write"|"reads"|"logical_reads"|"writes"|"client_interface_name"|"nt_domain"|"nt_user_name"|"client_net_address"|"local_net_address"|"dma_source_id"|"dma_manual_id"|"client_version"|"protocol_type"|"protocol_version"|"protocol_hex_version"'
Set-Content -Path $foldername\$dbsizes -Encoding utf8 -Value '"PKEY"|"database_name"|"type_desc"|"current_size_mb"|"dma_source_id"|"dma_manual_id"|"recovery_model_desc"'
Set-Content -Path $foldername\$dbServerDmvPerfmon -Encoding utf8 -Value '"PKEY"|"collection_time"|"available_mbytes"|"physicaldisk_avg_disk_bytes_read"|"physicaldisk_avg_disk_bytes_write"|"physicaldisk_avg_disk_bytes_read_sec"|"physicaldisk_avg_disk_bytes_write_sec"|"physicaldisk_disk_reads_sec"|"physicaldisk_disk_writes_sec"|"processor_idle_time_pct"|"processor_total_time_pct"|"processor_frequency"|"processor_queue_length"|"buffer_cache_hit_ratio"|"checkpoint_pages_sec"|"free_list_stalls_sec"|"page_life_expectancy"|"page_lookups_sec"|"page_reads_sec"|"page_writes_sec"|"user_connection_count"|"memory_grants_pending"|"target_server_memory_kb"|"total_server_memory_kb"|"batch_requests_sec"|"dma_source_id"|"dma_manual_id"'
Set-Content -Path $foldername\$databaseLevelBlockingFeatures -Encoding utf8 -Value '"PKEY"|"database_name"|"feature_name"|"is_enabled_or_used"|"occurance_count"|"dma_source_id"|"dma_manual_id"'
Set-Content -Path $foldername\$deepScanner -Encoding utf8 -Value '"PKEY"|"database_name"|"schema_name"|"object_name"|"object_type"|"incompatibility_type"|"severity"|"violation_count"|"dma_source_id"|"dma_manual_id"'

### Iterate through collections that could execute against multiple databases in the instance
$dbLoopCounter = 0
$totalDbCount = $dbNameArray.Count
foreach ($databaseName in $dbNameArray) {
    $dbLoopCounter++
    WriteLog -logLocation $foldername\$logFile -logMessage "Processing Database [$dbLoopCounter of $totalDbCount]: $databaseName ..." -logOperation "BOTH"
    ### Surround the databaseName variable with quotes to protect from values that have spaces in it
    $databaseName = '"{0}"' -f $databaseName
    $dbSqlVars = @("pkey=$pkey", "database=$databaseName", "dmaSourceId=$dmaSourceId", "dmaManualId=$manualUniqueId")
    if ($databaseName -inotmatch "tempdb") {
        WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Object Info for Database $databaseName ..." -logOperation "BOTH"
        Invoke-DmaSqlStep -StepName "ObjectList" -SqlFile "sql\objectList.sql" -DatabaseName $databaseName -OutputFilePath "$foldername\$objectList" -SqlcmdVars $dbSqlVars

        WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Table Info for Database $databaseName ..." -logOperation "BOTH"
        Invoke-DmaSqlStep -StepName "TableList" -SqlFile "sql\tableList.sql" -DatabaseName $databaseName -OutputFilePath "$foldername\$tableList" -SqlcmdVars $dbSqlVars

        WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Index Info for Database $databaseName ..." -logOperation "BOTH"
        Invoke-DmaSqlStep -StepName "IndexList" -SqlFile "sql\indexList.sql" -DatabaseName $databaseName -OutputFilePath "$foldername\$indexList" -SqlcmdVars $dbSqlVars

        WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Column Datatype Info for Database $databaseName ..." -logOperation "BOTH"
        Invoke-DmaSqlStep -StepName "ColumnDatatypes" -SqlFile "sql\columnDatatypes.sql" -DatabaseName $databaseName -OutputFilePath "$foldername\$columnDatatypes" -SqlcmdVars $dbSqlVars

        WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server User Connection Info for Database $databaseName ..." -logOperation "BOTH"
        Invoke-DmaSqlStep -StepName "UserConnectionInfo" -SqlFile "sql\userConnectionInfo.sql" -DatabaseName $databaseName -OutputFilePath "$foldername\$userConnectionList" -SqlcmdVars $dbSqlVars

        WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server DMV Perfmon Info for Database $databaseName ..." -logOperation "BOTH"
        Invoke-DmaSqlStep -StepName "DbServerDmvPerfmon" -SqlFile "sql\dbServerDmvPerfmon.sql" -DatabaseName $databaseName -OutputFilePath "$foldername\$dbServerDmvPerfmon" -SqlcmdVars $dbSqlVars

        WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Blocked Features for Database $databaseName ..." -logOperation "BOTH"
        Invoke-DmaSqlStep -StepName "DbServerFeaturesDatabaseLevel" -SqlFile "sql\dbServerFeaturesDatabaseLevel.sql" -DatabaseName $databaseName -OutputFilePath "$foldername\$databaseLevelBlockingFeatures" -SqlcmdVars $dbSqlVars

        WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Deep Postgres Migration Blocker Info for Database $databaseName ..." -logOperation "BOTH"
        Invoke-DmaSqlStep -StepName "TsqlPostgresDeepScanner" -SqlFile "sql\tsqlPostgresDeepScanner.sql" -DatabaseName $databaseName -OutputFilePath "$foldername\$deepScanner" -SqlcmdVars $dbSqlVars
    }
    WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Database Size Info for Database $databaseName ..." -logOperation "BOTH"
    Invoke-DmaSqlStep -StepName "DbSizes" -SqlFile "sql\dbSizes.sql" -DatabaseName $databaseName -OutputFilePath "$foldername\$dbsizes" -SqlcmdVars $dbSqlVars
}

### Need to execute certain files against tempdb to gather temp table information
if ($isCloudOrLinuxHost -eq "AZURE") {
    WriteLog -logLocation $foldername\$logFile -logMessage "Skipping SQL Server Temp Table Info...Unavailable in AZURE SQL Managed Instance." -logOperation "BOTH"
}
else {
    WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Temp Table Info..." -logOperation "BOTH"
    $tempdbVars = @("pkey=$pkey", "database=$databaseName", "dmaSourceId=$dmaSourceId", "dmaManualId=$manualUniqueId")
    Invoke-DmaSqlStep -StepName "TempdbTableList" -SqlFile "sql\tableList.sql" -DatabaseName "tempdb" -OutputFilePath "$foldername\$tableList" -SqlcmdVars $tempdbVars
}

if ($isCloudOrLinuxHost -eq "AZURE") {
    WriteLog -logLocation $foldername\$logFile -logMessage "Executing Azure-Specific Compute and Governance Stats..." -logOperation "BOTH"

    $azureDbRes = 'opdb' + '__' + 'AzureDbResourceStats' + $outputFileSuffix
    Set-Content -Path $foldername\$azureDbRes -Encoding utf8 -Value '"PKEY"|"end_time"|"avg_cpu_percent"|"avg_data_io_percent"|"avg_log_write_percent"|"max_worker_percent"|"max_session_percent"|"current_limit"|"current_storage_usage_db"|"dma_source_id"|"dma_manual_id"'
    Invoke-DmaSqlStep -StepName "AzureDbResourceStats" -SqlFile "sql\azureDbResourceStats.sql" -DatabaseName $dbname -OutputFilePath "$foldername\$azureDbRes" -SqlcmdVars $stdSqlVars

    $azureRes = 'opdb' + '__' + 'AzureResourceStats' + $outputFileSuffix
    Set-Content -Path $foldername\$azureRes -Encoding utf8 -Value '"PKEY"|"start_time"|"end_time"|"database_name"|"sku"|"avg_cpu_percent"|"avg_data_io_percent"|"avg_log_write_percent"|"max_worker_percent"|"max_session_percent"|"dtu_limit"|"dma_source_id"|"dma_manual_id"'
    Invoke-DmaSqlStep -StepName "AzureResourceStats" -SqlFile "sql\azureResourceStats.sql" -DatabaseName "master" -OutputFilePath "$foldername\$azureRes" -SqlcmdVars $stdSqlVars

    $azureGov = 'opdb' + '__' + 'AzureResourceGovernance' + $outputFileSuffix
    Set-Content -Path $foldername\$azureGov -Encoding utf8 -Value '"PKEY"|"database_id"|"logical_cpu_count"|"process_memory_limit_mb"|"max_global_index_size_mb"|"user_data_cap_gb"|"user_data_iops_cap"|"log_write_cap_mb_sec"|"dma_source_id"|"dma_manual_id"'
    Invoke-DmaSqlStep -StepName "AzureResourceGovernance" -SqlFile "sql\azureResourceGovernance.sql" -DatabaseName $dbname -OutputFilePath "$foldername\$azureGov" -SqlcmdVars $stdSqlVars

    $azurePool = 'opdb' + '__' + 'AzureElasticPoolStats' + $outputFileSuffix
    Set-Content -Path $foldername\$azurePool -Encoding utf8 -Value '"PKEY"|"end_time"|"elastic_pool_name"|"avg_cpu_percent"|"avg_data_io_percent"|"avg_log_write_percent"|"max_worker_percent"|"elastic_pool_dtu_limit"|"dma_source_id"|"dma_manual_id"'
    Invoke-DmaSqlStep -StepName "AzureElasticPoolStats" -SqlFile "sql\azureElasticPoolStats.sql" -DatabaseName "master" -OutputFilePath "$foldername\$azurePool" -SqlcmdVars $stdSqlVars
}

# Pull perfmon file if we are running from same server.  Generate empty file if running on remote server
# Capability does not exist yet to run against remote computer

if ($ignorePerfmon -eq "true") {
    WriteLog -logLocation $foldername\$logFile -logMessage "Skipping Perfmon Information (creating empty PerfMonData file)..." -logOperation "BOTH"
    if (($instancename -eq "MSSQLSERVER") -and ([string]$env:computername.toUpper() -ne [string]$machinename.toUpper())) {
        .\dmaSQLServerPerfmonDataset.ps1 -operation createemptyfile -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $manualUniqueId
    }
    else {
        .\dmaSQLServerPerfmonDataset.ps1 -operation createemptyfile -namedInstanceName $instancename -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $manualUniqueId
    }
}
else {
    WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving Perfmon Information (host='$env:computername', target='$machinename', instance='$instancename')..." -logOperation "BOTH"
    if (($instancename -eq "MSSQLSERVER") -and ([string]$env:computername.toUpper() -eq [string]$machinename.toUpper())) {
        .\dmaSQLServerPerfmonDataset.ps1 -operation collect -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $manualUniqueId
    }
    elseif (($instancename -ne "MSSQLSERVER") -and ([string]$env:computername.toUpper() -eq [string]$machinename.toUpper())) {
        .\dmaSQLServerPerfmonDataset.ps1 -operation collect -namedInstanceName $instancename -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $manualUniqueId
    }
    elseif (($instancename -eq "MSSQLSERVER") -and ([string]$env:computername.toUpper() -ne [string]$machinename.toUpper())) {
        WriteLog -logLocation $foldername\$logFile -logMessage "Host '$env:computername' differs from target '$machinename'; creating empty PerfMonData file..." -logOperation "BOTH"
        .\dmaSQLServerPerfmonDataset.ps1 -operation createemptyfile -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $manualUniqueId
    }
    elseif (($instancename -ne "MSSQLSERVER") -and ([string]$env:computername.toUpper() -ne [string]$machinename.toUpper())) {
        WriteLog -logLocation $foldername\$logFile -logMessage "Host '$env:computername' differs from target '$machinename'; creating empty PerfMonData file..." -logOperation "BOTH"
        .\dmaSQLServerPerfmonDataset.ps1 -operation createemptyfile -namedInstanceName $instancename -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $manualUniqueId
    }
}

<# Getting HW Specs. #>
if ($isCloudOrLinuxHost -eq "AZURE") {
    WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server HW Shape Info for Machine $machinename via T-SQL..." -logOperation "BOTH"
    Set-Content -Path $foldername\$computerSpecsFile -Encoding utf8 -Value '"pkey"|"dma_source_id"|"dma_manual_id"|"MachineName"|"PhysicalCpuCount"|"LogicalCpuCount"|"TotalOSMemoryMB"'
    Invoke-DmaSqlStep -StepName "MachineSpecsTsql" -SqlFile "sql\machineSpecsTsql.sql" -DatabaseName "master" -OutputFilePath "$foldername\$computerSpecsFile" -SqlcmdVars $stdSqlVars
}
elseif ($isCloudOrLinuxHost -eq "LINUX") {
    WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server HW Shape Info for Machine $machinename via T-SQL..." -logOperation "BOTH"
    Set-Content -Path $foldername\$computerSpecsFile -Encoding utf8 -Value '"pkey"|"dma_source_id"|"dma_manual_id"|"MachineName"|"PhysicalCpuCount"|"LogicalCpuCount"|"TotalOSMemoryMB"'
    Invoke-DmaSqlStep -StepName "MachineSpecsTsql" -SqlFile "sql\machineSpecsTsql.sql" -DatabaseName "master" -OutputFilePath "$foldername\$computerSpecsFile" -SqlcmdVars $stdSqlVars
}
else {
    WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server HW Shape Info for Machine $machinename ..." -logOperation "BOTH"
    .\dmaSQLServerHWSpecs.ps1 -computerName $machinename -outputPath $foldername\$computerSpecsFile -logLocation $foldername\$logFile -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $manualUniqueId -requestCreds:$collectVMSpecs
    if (-not (Test-Path -Path $foldername\$computerSpecsFile) -or ((Get-Content -Path $foldername\$computerSpecsFile).Count -le 1)) {
        WriteLog -logLocation $foldername\$logFile -logMessage "WMI/CIM HW collection returned no data; falling back to T-SQL machineSpecsTsql.sql..." -logOperation "BOTH"
        Set-Content -Path $foldername\$computerSpecsFile -Encoding utf8 -Value '"pkey"|"dma_source_id"|"dma_manual_id"|"MachineName"|"PhysicalCpuCount"|"LogicalCpuCount"|"TotalOSMemoryMB"'
        Invoke-DmaSqlStep -StepName "MachineSpecsTsqlFallback" -SqlFile "sql\machineSpecsTsql.sql" -DatabaseName "master" -OutputFilePath "$foldername\$computerSpecsFile" -SqlcmdVars $stdSqlVars
    }
}

WriteLog -logLocation $foldername\$logFile -logMessage "Remove special characters and UTF8 BOM from extracted files..." -logOperation "BOTH"

# This portion of the script re-writes the original logic to handle large CSV files efficiently by using
# a streaming (chunked) approach with a temporary file, preventing high memory usage
# caused by loading the entire file content into a single string or byte array.

# Define the UTF8 encoding without the Byte Order Mark (BOM)
# This matches the result of the original $utf8 = New-Object System.Text.UTF8Encoding $false
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

# Define the Line Feed character (`n) to force Unix-style line endings
$LF = "`n"

# Use Get-ChildItem to safely iterate through files
foreach ($file in Get-ChildItem -Path $foldername\*.csv -ErrorAction Stop) {
    $inputFile = $file.FullName
    $tempFile = "$inputFile.tmp"
    WriteLog -logLocation $foldername\$logFile -logMessage "     Processing $($file.Name)..." -logOperation "BOTH"

    # Step 1: Stream the normalized content to a temporary file
    $writer = $null
    $lineCount = 0
    try {
        # Open the temporary file for writing using the specific UTF8-No-BOM encoding
        # This keeps only a small buffer of the file content in memory at any time.
        $writer = New-Object System.IO.StreamWriter -ArgumentList $tempFile, $false, $utf8NoBom

        # Read the content line by line (Get-Content is streaming by default when not using -Raw)
        $lines = Get-Content -Path $inputFile

        $firstLine = $true
        foreach ($line in $lines) {
            $lineCount++
            # Explicitly remove any Carriage Return characters (`r) to ensure strict LF-only line endings,
            $cleanLine = $line.Replace("`r", "")

            # The original -join "`n" puts a LF *between* every line.
            # We simulate this by prepending LF to every line after the first.
            if (-not $firstLine) {
                $writer.Write($LF)
            }

            # Write the raw, cleaned line content
            $writer.Write($cleanLine)
            $firstLine = $false
        }

        # The original code added a final trailing line feed: + "`n"
        if (-not $firstLine) {
            $writer.Write($LF)
        }
    }
    catch {
        WriteLog -logLocation $foldername\$logFile -logMessage "          Error processing file $($file.Name): $($_.Exception.Message)" -logOperation "BOTH"
        continue
    }
    finally {
        # IMPORTANT: Always close the StreamWriter to flush the buffer and release the file lock
        if ($writer) {
            $writer.Close()
            $writer.Dispose()
        }
    }

    # Step 2: Replace the original file with the temporary file
    try {
        # Delete the original file
        Remove-Item $inputFile -Force -ErrorAction Stop
        # Rename the temporary file to the original filename
        Rename-Item $tempFile -NewName $file.Name -Force -ErrorAction Stop

        $finalBytes = (Get-Item -Path $inputFile).Length
        $dataRowCount = [Math]::Max(0, $lineCount - 1)
        $script:CsvManifestStats += [PSCustomObject]@{
            FileName  = $file.Name
            DataRows  = $dataRowCount
            TotalRows = $lineCount
            SizeBytes = $finalBytes
        }
        WriteLog -logLocation $foldername\$logFile -logMessage "          $($file.Name) successfully processed (DataRows=$dataRowCount, SizeBytes=$finalBytes)..." -logOperation "BOTH"
    }
    catch {
        WriteLog -logLocation $foldername\$logFile -logMessage "          Failed to replace the original file $($file.Name). Temp file may remain. Error: $($_.Exception.Message)" -logOperation "BOTH"
        # Clean up the temp file if the rename failed
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}

WriteLog -logLocation $foldername\$logFile -logMessage "Creating the manifest..." -logOperation "BOTH"
foreach ($file in Get-ChildItem -Path $foldername\*.csv) {
    $inputFile = Split-Path -Leaf $file
    createManifestFile -manifestFileLocation $foldername -manifestOutputFileName $manifestFile -manifestedFileName $inputFile
}

WriteLog -logLocation $foldername\$logFile -logMessage "Checking for error messages within collection files..." -logOperation "BOTH"
$detectedErrors = @()
$missingFiles = @()

foreach ($stepErr in $script:StepExecutionErrors) {
    $detectedErrors += [PSCustomObject]@{
        File  = "$($stepErr.File) [$($stepErr.SqlFile) on $($stepErr.Database)]"
        Error = $stepErr.Error
    }
    $totalErrorCount = $totalErrorCount + 1
}

foreach ($file in Get-ChildItem -Path $foldername\*.csv, $foldername\*.log -Exclude $logFile, $sqlErrorLogFile) {
    $inputFile = Split-Path -Leaf $file
    $errorContentCount = 0
    [regex]$pattern = "(Msg(\s\d*)(.)(\n|\s)Level(\s\d*.)(\n|\s)State(\s\d*)(.)(\n|\s))"
    $hasError = Select-String -Path "$foldername\$inputFile" -Pattern $pattern -Quiet
    if ($hasError) {
        $errorContentCount = 1
        $errSample = Select-String -Path "$foldername\$inputFile" -Pattern "Msg\s+\d+,\s*Level\s+\d+.*" | Select-Object -First 3
        $errSummary = ""
        if ($errSample) {
            $errSummary = ($errSample | ForEach-Object { $_.Line.Trim() }) -join " | "
        }
        else {
            $errSummary = "SQL Engine Error (Msg/Level/State detected)"
        }
        $detectedErrors += [PSCustomObject]@{
            File  = $inputFile
            Error = $errSummary
        }
        WriteLog -logLocation $foldername\$logFile -logMessage "     [ERROR] Errors found in collection file $inputFile :" -logOperation "BOTH"
        WriteLog -logLocation $foldername\$logFile -logMessage "             $errSummary" -logOperation "BOTH"
        WriteLog -logLocation $foldername\$sqlErrorLogFile -logMessage "     Errors found within collection $inputFile :" -logOperation "FILE"
        WriteLog -logLocation $foldername\$sqlErrorLogFile -logMessage "             $errSummary" -logOperation "FILE"
    }
    else {
        WriteLog -logLocation $foldername\$sqlErrorLogFile -logMessage "Checking for error messages within collection $inputFile ... OK" -logOperation "FILE"
    }
    $totalErrorCount = $totalErrorCount + $errorContentCount
}

WriteLog -logLocation $foldername\$logFile -logMessage "Checking for the presence of all required files..." -logOperation "BOTH"
foreach ($directory in $outputFileArray) {
    if (Test-Path -Path $PSScriptRoot\$foldername\$directory) {
        WriteLog -logLocation $foldername\$logFile -logMessage "  File $directory exists" -logOperation "FILE"
    }
    else {
        WriteLog -logLocation $foldername\$logFile -logMessage "  [ERROR] Required file $directory does not exist!" -logOperation "BOTH"
        $totalErrorCount = $totalErrorCount + 1
        $missingFiles += $directory
    }
}

if ($totalErrorCount -gt 0) {
    $zippedopfolder = $foldername + '_ERROR.zip'
}
else {
    $zippedopfolder = $foldername + '.zip'
}

# Generate Diagnostic Collection Summary
$totalCollectionElapsedSec = [Math]::Round(((Get-Date) - $script:CollectionStartTime).TotalSeconds, 2)
$totalSqlStepMs = ($script:StepTelemetry | Measure-Object -Property DurationMs -Sum).Sum
if ($null -eq $totalSqlStepMs) { $totalSqlStepMs = 0 }

$summaryFile = "$foldername\COLLECTION_SUMMARY.txt"
$summaryLines = @()
$summaryLines += "================================================================================"
$summaryLines += "               DMA SQL Server Assessment Collection Summary                     "
$summaryLines += "================================================================================"
$summaryLines += "Timestamp:           $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
$summaryLines += "Total Duration:      $totalCollectionElapsedSec sec (SQL Steps: $totalSqlStepMs ms across $($script:StepTelemetry.Count) step executions)"
$summaryLines += "Server Instance:     $serverName"
$summaryLines += "Machine Name:        $machinename"
$summaryLines += "Instance Name:       $instancename"
$summaryLines += "SQL Version:         $dbversion (Product: $isValidSQLInstanceVersion, HostType: $isCloudOrLinuxHost)"
$summaryLines += "Collection User:     $(if ($collectionUserName) { $collectionUserName } elseif ($useEntraIDAuthentication) { $entraIDUserName } else { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name })"
$summaryLines += "Target Scope:        $database"
$summaryLines += "Databases Scanned:   $($dbNameArray.Count) ($($dbNameArray -join ', '))"
$summaryLines += "Databases Skipped:   $($dbNameNoAccessArray.Count)"
if ($dbNameNoAccessArray.Count -gt 0) {
    $summaryLines += "  Skipped Databases (missing HAS_DBACCESS):"
    foreach ($sk in $dbNameNoAccessArray) {
        $summaryLines += "    - $sk"
    }
}
if ($script:PermissionWarnings.Count -gt 0) {
    $summaryLines += "--------------------------------------------------------------------------------"
    $summaryLines += "PRE-FLIGHT PERMISSION WARNINGS ($($script:PermissionWarnings.Count)):"
    foreach ($pw in $script:PermissionWarnings) {
        $summaryLines += "  * $pw"
    }
}
$summaryLines += "--------------------------------------------------------------------------------"
if ($totalErrorCount -eq 0) {
    $summaryLines += "Collection Status:   SUCCESS (0 errors detected)"
    $summaryLines += "Output Archive:      $zippedopfolder"
}
else {
    $summaryLines += "Collection Status:   COMPLETED WITH ERRORS ($totalErrorCount issue(s) detected)"
    $summaryLines += "Output Archive:      $zippedopfolder"
    $summaryLines += ""
    $summaryLines += "DIAGNOSTIC FINDINGS & REMEDIATION:"
    if ($detectedErrors.Count -gt 0) {
        $summaryLines += "  [SQL Execution Errors Detected]:"
        foreach ($de in $detectedErrors) {
            $summaryLines += "    * File: $($de.File)"
            $summaryLines += "      Error: $($de.Error)"
            if ($de.Error -match "xp_readerrorlog") {
                $summaryLines += "      Remediation: GRANT EXECUTE ON master.dbo.xp_readerrorlog TO [$collectionUserName] or run as sysadmin."
            }
            elseif ($de.Error -match "sys\.sql_expression_dependencies") {
                $summaryLines += "      Remediation: GRANT VIEW ANY DEFINITION TO [$collectionUserName] or run as sysadmin."
            }
            elseif ($de.Error -match "permission was denied") {
                $summaryLines += "      Remediation: Ensure collection login has VIEW SERVER STATE and VIEW ANY DATABASE permissions."
            }
        }
    }
    if ($missingFiles.Count -gt 0) {
        $summaryLines += "  [Missing Expected Output Files]:"
        foreach ($mf in $missingFiles) {
            $summaryLines += "    * $mf"
        }
    }
    if ($dbNameNoAccessArray.Count -gt 0) {
        $summaryLines += "  [Database Access Limitations]:"
        $summaryLines += "    * $($dbNameNoAccessArray.Count) database(s) skipped because collection login lacks CONNECT / HAS_DBACCESS permission."
        $summaryLines += "      Remediation: Run createUserWithSQLAuth.ps1 against all user databases or execute assessment as sysadmin."
    }
}
$summaryLines += "--------------------------------------------------------------------------------"
$summaryLines += "STEP EXECUTION TELEMETRY ($($script:StepTelemetry.Count) steps):"
foreach ($st in $script:StepTelemetry) {
    $summaryLines += ("  [{0,-5}] {1,-30} | DB={2,-22} | {3,6} ms | Rows={4,6} | {5}" -f $st.Status, $st.StepName, $st.Database, $st.DurationMs, $st.RowsAdded, $st.SqlFile)
}
$summaryLines += "--------------------------------------------------------------------------------"
$summaryLines += "CSV OUTPUT MANIFEST ($($script:CsvManifestStats.Count) files):"
foreach ($cm in ($script:CsvManifestStats | Sort-Object FileName)) {
    $summaryLines += ("  {0,-78} | DataRows={1,7} | Bytes={2,10}" -f $cm.FileName, $cm.DataRows, $cm.SizeBytes)
}
$summaryLines += "================================================================================"

$summaryText = $summaryLines -join [Environment]::NewLine
Set-Content -Path $summaryFile -Encoding utf8 -Value $summaryText
Add-Content -Path "$foldername\$logFile" -Encoding utf8 -Value $summaryText

Write-Host ""
Write-Host $summaryText -ForegroundColor $(if ($totalErrorCount -gt 0) { "Yellow" } else { "Green" })
Write-Host ""

if ($powerShellVersion -ge 5) {

    if (([string]::IsNullorEmpty($outputDirectory)) -or ($outputDirectory -eq "default")) {
        WriteLog -logLocation $foldername\$logFile -logMessage "Zipping Output to $zippedopfolder..." -logOperation "BOTH"
        Compress-Archive -Path $foldername\*.csv, $foldername\*.log, $foldername\*.txt -DestinationPath $zippedopfolder
		$customOutputDir = 0
    } else {
        if ((Test-Path -Path $outputDirectory) -and ($outputDirectory -ne "default")) {
            WriteLog -logLocation $foldername\$logFile -logMessage "Zipping Output to $outputDirectory\$zippedopfolder..." -logOperation "BOTH"
            Compress-Archive -Path $foldername\*.csv, $foldername\*.log, $foldername\*.txt -DestinationPath $outputDirectory\$zippedopfolder
			$customOutputDir = 1
        } else {
            WriteLog -logLocation $foldername\$logFile -logMessage "Specified $outputDirectory is not valid.  Zipping Output to default directory $PSScriptRoot\$zippedopfolder..." -logOperation "BOTH"
            Compress-Archive -Path $foldername\*.csv, $foldername\*.log, $foldername\*.txt -DestinationPath $zippedopfolder
			$customOutputDir = 0
        }
    }

    if (Test-Path -Path $zippedopfolder) {
        WriteLog -logLocation $foldername\$logFile -logMessage "Removing directory $foldername..." -logOperation "MESSAGE"
        Remove-Item -Path $foldername -Recurse -Force
    }
    if (Test-Path -Path $env:TEMP\tempDisk.csv) {
        WriteLog -logLocation $foldername\$logFile -logMessage "Clean up Temp File area..." -logOperation "MESSAGE"
        Remove-Item -Path $env:TEMP\tempDisk.csv
    }

    WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "MESSAGE"
    WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "MESSAGE"

	if ($customOutputDir -eq 0) {
		WriteLog -logLocation $foldername\$logFile -logMessage "Return file $PSScriptRoot\$zippedopfolder" -logOperation "MESSAGE"
		WriteLog -logLocation $foldername\$logFile -logMessage "to Google to complete assessment" -logOperation "MESSAGE"
    } else {
		WriteLog -logLocation $foldername\$logFile -logMessage "Return file $outputDirectory\$zippedopfolder" -logOperation "MESSAGE"
		WriteLog -logLocation $foldername\$logFile -logMessage "to Google to complete assessment" -logOperation "MESSAGE"
	}
	WriteLog -logLocation $foldername\$logFile -logMessage "Collection Complete..." -logOperation "MESSAGE"
}
else {
    WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "MESSAGE"
    WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "MESSAGE"
    WriteLog -logLocation $foldername\$logFile -logMessage "Please manually zip the files in $foldername and" -logOperation "MESSAGE"
    WriteLog -logLocation $foldername\$logFile -logMessage "return to Google to complete assessment" -logOperation "MESSAGE"
    WriteLog -logLocation $foldername\$logFile -logMessage "Collection Complete..." -logOperation "MESSAGE"
}

if (Test-Path -Path $script:BootstrapLogFile) {
    Remove-Item -Path $script:BootstrapLogFile -Force -ErrorAction SilentlyContinue
}

if (-not ([string]::IsNullOrEmpty($originalLocation)) -and ($originalLocation -ne $PSScriptRoot)) {
    ### Navigating back to the original directory location
    $currentTimestamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    Write-Host "$currentTimestamp   Changing directory back to: $originalLocation"
    Pop-Location
}

if ($null -ne $script:DmaEntraOdbcConnection) {
    $script:DmaEntraOdbcConnection.Close()
    $script:DmaEntraOdbcConnection.Dispose()
}

Exit 0

