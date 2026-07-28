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

# Establish a persistent shared ADO.NET connection to guarantee exactly ONE Entra MFA prompt across all 50+ queries
function sqlcmd {
    $serverInstance = $serverName
    $inputFile = ""
    $dbName = "master"
    $variables = @{}

    for ($idx = 0; $idx -lt $args.Count; $idx++) {
        $token = $args[$idx]
        if ($token -eq "-S") { $serverInstance = $args[++$idx] }
        elseif ($token -eq "-i") { $inputFile = $args[++$idx] }
        elseif ($token -eq "-d") { $dbName = $args[++$idx] }
        elseif ($token -eq "-v") {
            while ($idx + 1 -lt $args.Count -and $args[$idx+1] -notmatch "^-") {
                $assignment = $args[++$idx]
                if ($assignment -match "=") {
                    $parts = $assignment.Split('=', 2)
                    $variables[$parts[0].Trim()] = $parts[1].Trim()
                }
            }
        }
    }

    if (-not $global:persistentSqlConn) {
        Import-Module SqlServer -ErrorAction SilentlyContinue
        $connStr = "Server=$serverInstance;Database=$dbName;TrustServerCertificate=True"
        if ($useEntraIDAuthentication) {
            $connStr += ";Authentication=Active Directory Interactive"
            if ($entraUpn) { $connStr += ";User ID=$entraUpn" }
        } elseif ($env:SQLCMDUSER -and $env:SQLCMDPASSWORD) {
            $connStr += ";User ID=$env:SQLCMDUSER;Password=$env:SQLCMDPASSWORD"
        } else {
            $connStr += ";Integrated Security=True"
        }

        try {
            $global:persistentSqlConn = New-Object Microsoft.Data.SqlClient.SqlConnection($connStr)
        } catch {
            $global:persistentSqlConn = New-Object System.Data.SqlClient.SqlConnection($connStr)
        }
        $global:persistentSqlConn.Open()
    } else {
        if ($global:persistentSqlConn.Database -ne $dbName) {
            $global:persistentSqlConn.ChangeDatabase($dbName)
        }
    }

    if ($inputFile -and (Test-Path $inputFile)) {
        $query = (Get-Content $inputFile -Raw)
        foreach ($varKey in $variables.Keys) {
            $query = $query.Replace("`$($varKey)", "$($variables[$varKey])")
        }

        $cmd = $global:persistentSqlConn.CreateCommand()
        $cmd.CommandText = $query
        $cmd.CommandTimeout = 300

        try {
            $reader = $cmd.ExecuteReader()
            while ($reader.Read()) {
                $rowVals = @()
                for ($c = 0; $c -lt $reader.FieldCount; $c++) {
                    $rowVals += "$($reader.GetValue($c))"
                }
                $rowVals -join "|"
            }
            $reader.Close()
        } catch {
            Write-Error $_.Exception.Message
        }
    }
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
    Write-Output "Server parameter $serverName is empty.  Ensure that the parameter is provided"
    Exit 1
}
elseif ([string]::IsNullorEmpty($collectionUserName) -and (-not $useWindowsAuthentication) -and (-not $useEntraIDAuthentication)) {
    Write-Output "Collection Username parameter $collectionUserName is empty."
    Write-Output "Ensure that the parameter is provided or -useWindowsAuthentication is specified"
    Exit 1
}
elseif (((checkStringForSpecialChars -inputString $manualUniqueId) -eq "fail") -and (![string]::IsNullorEmpty($manualUniqueId))) {
    Write-Output "Manual Unique Id parameter $manualUniqueId contains spaces or special characters.  Ensure that the parameter contains only letters, numbers and no spaces"
    Exit 1
}
else {
    ### Surround the databaseName variable with quotes to protect from values that have spaces in it
    $databaseNameFilter = '"{0}"' -f $database
    if (([string]::IsNullorEmpty($port)) -or ($port -eq "default")) {
        WriteLog -logMessage "Retrieving Metadata Information from $serverName" -logOperation "MESSAGE"
        $inputServerName = $serverName
        $folderObj = sqlcmd -S $serverName -i sql\foldername.sql -d master -C -l 30 -W -m 1 -u -w 32768 -v database=$databaseNameFilter @sqlcmdAuthArgs | findstr /v /c:"---"
        $validSQLInstanceVersionCheckArray = @(sqlcmd -S $serverName -i sql\checkValidInstanceVersion.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 @sqlcmdAuthArgs)
        $dbNameArray = @(sqlcmd -S $serverName -i sql\getDBList.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 -v database=$databaseNameFilter -v hasdbaccess=1 @sqlcmdAuthArgs)
        $dbNameNoAccessArray = @(sqlcmd -S $serverName -i sql\getDBList.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 -v database=$databaseNameFilter -v hasdbaccess=0 @sqlcmdAuthArgs)
        $dmaSourceIdObj = @(sqlcmd -S $serverName -i sql\getDmaSourceId.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 @sqlcmdAuthArgs)

        if ([string]$database -ne "all") {
            $validDBObj = sqlcmd -S $serverName -i sql\checkValidDatabase.sql -C -l 30 -W -m 1 -u -h-1 -w 32768 -v database=$databaseNameFilter @sqlcmdAuthArgs | findstr /v /c:"-"
            if (([string]::IsNullorEmpty($folderObj)) -or ([int]$validDBObj -eq 0)) {
                Write-Output " "
                Write-Output "SQL Server Database $database not valid.  Exiting Script...."
                Exit 1
            }
        }
    }
    else {
        $inputServerName = $serverName
        $serverName = "$serverName,$port"
        WriteLog -logMessage "Retrieving Metadata Information from $serverName" -logOperation "MESSAGE"
        $folderObj = sqlcmd -S $serverName -i sql\foldername.sql -d master -C -l 30 -W -m 1 -u -w 32768 -v database=$databaseNameFilter @sqlcmdAuthArgs | findstr /v /c:"---"
        $validSQLInstanceVersionCheckArray = @(sqlcmd -S $serverName -i sql\checkValidInstanceVersion.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 @sqlcmdAuthArgs)
        $dbNameArray = @(sqlcmd -S $serverName -i sql\getDBList.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 -v database=$databaseNameFilter -v hasdbaccess=1 @sqlcmdAuthArgs)
        $dbNameNoAccessArray = @(sqlcmd -S $serverName -i sql\getDBList.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 -v database=$databaseNameFilter -v hasdbaccess=0 @sqlcmdAuthArgs)
        $dmaSourceIdObj = @(sqlcmd -S $serverName -i sql\getDmaSourceId.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 @sqlcmdAuthArgs)

        if ([string]$database -ne "all") {
            $validDBObj = sqlcmd -S $serverName -i sql\checkValidDatabase.sql -C -l 30 -W -m 1 -u -h-1 -w 32768 -v database=$databaseNameFilter @sqlcmdAuthArgs | findstr /v /c:"-"
            if (([string]::IsNullorEmpty($folderObj)) -or ([int]$validDBObj -eq 0)) {
                Write-Output " "
                Write-Output "SQL Server Database $database not valid.  Exiting Script...."
                Exit 1
            }
        }
    }
}

if ([string]::IsNullorEmpty($folderObj)) {
    Write-Output " "
    Write-Output "Connection Error to SQL Server $serverName.  Exiting Script...."
    Exit 1
}

<# Fixup Variables to build folder name, check valid version, check if cloud #>
$splitobj = $folderObj[1].Split('')
$values = $splitobj | ForEach-Object { if ($_.Trim() -ne '') { $_ } }

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

$op_version = "4.3.47"

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
$tranLogBkupCountByDayByHour = 'opdb' + '__' + 'TranLogBkupCountByHourByDay' + $outputFileSuffix
$tranLogBkupSizeByDayByHour = 'opdb' + '__' + 'TranLogBkupSizeByHourByDay' + $outputFileSuffix
$databaseLevelBlockingFeatures = 'opdb' + '__' + 'DatabaseLevelBlockFeatures' + $outputFileSuffix

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
    $computerSpecsFile
    $tranLogBkupCountByDayByHour,
    $tranLogBkupSizeByDayByHour,
    $databaseLevelBlockingFeatures)

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

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Installed Components..." -logOperation "BOTH"
Set-Content -Path $foldername\$compFileName -Encoding utf8 -Value '"PKEY"|"physical_server_name"|"sql_instance_name"|"sql_server_services"|"current_service_status"|"status_date_time"|"dma_source_id"|"dma_manual_id"'
sqlcmd -S $serverName -i sql\componentsInstalled.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$compFileName -Encoding utf8

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Properties..." -logOperation "BOTH"
Set-Content -Path $foldername\$srvFileName -Encoding utf8 -Value '"PKEY"|"property_name"|"property_value"|"dma_source_id"|"dma_manual_id"'
sqlcmd -S $serverName -i sql\serverProperties.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$srvFileName -Encoding utf8

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server CloudSQL Unsupported Flag Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$dbServerFlags -Encoding utf8 -Value '"PKEY"|"flag_name"|"value"|"value_in_use"|"description"|"dma_source_id"|"dma_manual_id"'
sqlcmd -S $serverName -i sql\dbServerUnsupportedFlags.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$dbServerFlags -Encoding utf8

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Blocked Features in Use..." -logOperation "BOTH"
Set-Content -Path $foldername\$blockingFeatures -Encoding utf8 -Value '"PKEY"|"Features"|"Is_EnabledOrUsed"|"Count"|"dma_source_id"|"dma_manual_id"'
sqlcmd -S $serverName -i sql\dbServerFeatures.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$blockingFeatures -Encoding utf8

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Linked Server Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$linkedServers -Encoding utf8 -Value '"pkey"|"name"|"product"|"provider"|"data_source"|"location"|"provider_string"|"catalog"|"dma_source_id"|"dma_manual_id"'
sqlcmd -S $serverName -i sql\linkedServersDetail.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$linkedServers -Encoding utf8

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Cluster Node Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$dbClusterNodes -Encoding utf8 -Value '"pkey"|"node_name"|"status"|"status_description"|"dma_source_id"|"dma_manual_id"'
sqlcmd -S $serverName -i sql\dbClusterNodes.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$dbClusterNodes -Encoding utf8

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server DBCC Trace Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$dbccTraceFlg -Encoding utf8 -Value '"PKEY"|"name"|"status"|"global"|"session"|"dma_source_id"|"dma_manual_id"'
sqlcmd -S $serverName -i sql\dbccTraceFlags.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$dbccTraceFlg -Encoding utf8

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Disk Volume Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$diskVolumeInfo -Encoding utf8 -Value '"PKEY"|"volume_mount_point"|"file_system_type"|"logical_volume_name"|"total_size_gb"|"available_size_gb"|"space_free_pct"|"cluster_block_size"|"dma_source_id"|"dma_manual_id"'
sqlcmd -S $serverName -i sql\diskVolumeInfo.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$diskVolumeInfo -Encoding utf8

WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Configuration Info..." -logOperation "BOTH"
Set-Content -Path $foldername\$dbServerConfig -Encoding utf8 -Value '"pkey"|"configuration_id"|"name"|"value"|"minimum"|"maximum"|"value_in_use"|"description"|"dma_source_id"|"dma_manual_id"'
sqlcmd -S $serverName -i sql\dbServerConfigurationSettings.sql -d master -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$dbServerConfig -Encoding utf8

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
    sqlcmd -S $serverName -i sql\dbServerTranLogBackupCountByDayByHour.sql -d msdb -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$tranLogBkupCountByDayByHour -Encoding utf8
    sqlcmd -S $serverName -i sql\dbServerTranLogBackupSizeByDayByHour.sql -d msdb -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$tranLogBkupSizeByDayByHour -Encoding utf8
}

### First establish headers for the collection files which could execute against multiple databases in the instance
Set-Content -Path $foldername\$objectList -Encoding utf8 -Value '"PKEY"|"database_name"|"schema_name"|"object_name"|"object_type"|"object_type_desc"|"object_count"|"lines_of_code"|"associated_table_name"|"dma_source_id"|"dma_manual_id"'
Set-Content -Path $foldername\$tableList -Encoding utf8 -Value '"PKEY"|"database_name"|"schema_name"|"table_name"|"partition_count"|"is_memory_optimized"|"temporal_type"|"is_external"|"lock_escalation"|"is_tracked_by_cdc"|"text_in_row_limit"|"is_replicated"|"row_count"|"data_compression"|"total_space_mb"|"used_space_mb"|"unused_space_mb"|"dma_source_id"|"dma_manual_id"|"partition_type"|"is_temp_table"'
Set-Content -Path $foldername\$indexList -Encoding utf8 -Value '"PKEY"|"database_name"|"schema_name"|"table_name"|"index_name"|"index_type"|"is_primary_key"|"is_unique"|"fill_factor"|"allow_page_locks"|"has_filter"|"data_compression"|"data_compression_desc"|"is_partitioned"|"count_key_ordinal"|"count_partition_ordinal"|"count_is_included_column"|"total_space_mb"|"dma_source_id"|"dma_manual_id"|"is_computed_index"|"is_index_on_view"'
Set-Content -Path $foldername\$columnDatatypes -Encoding utf8 -Value '"PKEY"|"database_name"|"schema_name"|"table_name"|"datatype"|"max_length"|"precision"|"scale"|"is_computed"|"is_filestream"|"is_masked"|"encryption_type"|"is_sparse"|"rule_object_id"|"column_count"|"dma_source_id"|"dma_manual_id"'
Set-Content -Path $foldername\$userConnectionList -Encoding utf8 -Value '"PKEY"|"database_name"|"is_user_process"|"host_name"|"program_name"|"login_name"|"num_reads"|"num_writes"|"last_read"|"last_write"|"reads"|"logical_reads"|"writes"|"client_interface_name"|"nt_domain"|"nt_user_name"|"client_net_address"|"local_net_address"|"dma_source_id"|"dma_manual_id"|"client_version"|"protocol_type"|"protocol_version"|"protocol_hex_version"'
Set-Content -Path $foldername\$dbsizes -Encoding utf8 -Value '"PKEY"|"database_name"|"type_desc"|"current_size_mb"|"dma_source_id"|"dma_manual_id"|"recovery_model_desc"'
Set-Content -Path $foldername\$dbServerDmvPerfmon -Encoding utf8 -Value '"PKEY"|"collection_time"|"available_mbytes"|"physicaldisk_avg_disk_bytes_read"|"physicaldisk_avg_disk_bytes_write"|"physicaldisk_avg_disk_bytes_read_sec"|"physicaldisk_avg_disk_bytes_write_sec"|"physicaldisk_disk_reads_sec"|"physicaldisk_disk_writes_sec"|"processor_idle_time_pct"|"processor_total_time_pct"|"processor_frequency"|"processor_queue_length"|"buffer_cache_hit_ratio"|"checkpoint_pages_sec"|"free_list_stalls_sec"|"page_life_expectancy"|"page_lookups_sec"|"page_reads_sec"|"page_writes_sec"|"user_connection_count"|"memory_grants_pending"|"target_server_memory_kb"|"total_server_memory_kb"|"batch_requests_sec"|"dma_source_id"|"dma_manual_id"'
Set-Content -Path $foldername\$databaseLevelBlockingFeatures -Encoding utf8 -Value '"PKEY"|"database_name"|"feature_name"|"is_enabled_or_used"|"occurance_count"|"dma_source_id"|"dma_manual_id"'

### Iterate through collections that could execute against multiple databases in the instance
foreach ($databaseName in $dbNameArray) {
    ### Surround the databaseName variable with quotes to protect from values that have spaces in it
    $databaseName = '"{0}"' -f $databaseName
    if ($databaseName -inotmatch "tempdb") {
        WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Object Info for Database $databaseName ..." -logOperation "BOTH"
        sqlcmd -S $serverName -i sql\objectList.sql -d $databaseName -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey database=$databaseName dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$objectList -Encoding utf8

        WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Table Info for Database $databaseName ..." -logOperation "BOTH"
        sqlcmd -S $serverName -i sql\tableList.sql -d $databaseName -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey database=$databaseName dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$tableList -Encoding utf8

        WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Index Info for Database $databaseName ..." -logOperation "BOTH"
        sqlcmd -S $serverName -i sql\indexList.sql -d $databaseName -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey database=$databaseName dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$indexList -Encoding utf8

        WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Column Datatype Info for Database $databaseName ..." -logOperation "BOTH"
        sqlcmd -S $serverName -i sql\columnDatatypes.sql -d $databaseName -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey database=$databaseName dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$columnDatatypes -Encoding utf8

        WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server User Connection Info for Database $databaseName ..." -logOperation "BOTH"
        sqlcmd -S $serverName -i sql\userConnectionInfo.sql -d $databaseName -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey database=$databaseName dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$userConnectionList -Encoding utf8

        WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server DMV Perfmon Info for Database $databaseName ..." -logOperation "BOTH"
        sqlcmd -S $serverName -i sql\dbServerDmvPerfmon.sql -d $databaseName -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey database=$databaseName dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$dbServerDmvPerfmon -Encoding utf8

        WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Blocked Features for Database $databaseName ..." -logOperation "BOTH"
        sqlcmd -S $serverName -i sql\dbServerFeaturesDatabaseLevel.sql -d $databaseName -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey database=$databaseName dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$databaseLevelBlockingFeatures -Encoding utf8
    }
    WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Database Size Info for Database $databaseName ..." -logOperation "BOTH"
    sqlcmd -S $serverName -i sql\dbSizes.sql -d $databaseName -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey database=$databaseName dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$dbsizes -Encoding utf8
}

### Need to execute certain files against tempdb to gather temp table information
if ($isCloudOrLinuxHost -eq "AZURE") {
    WriteLog -logLocation $foldername\$logFile -logMessage "Skipping SQL Server Temp Table Info...Unavailable in AZURE SQL Managed Instance." -logOperation "BOTH"
}
else {
    WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server Temp Table Info..." -logOperation "BOTH"
    sqlcmd -S $serverName -i sql\tableList.sql -d tempdb -C -l 30 -W -m 1 -u -h-1 -w 32768 -v pkey=$pkey database=$databaseName dmaSourceId=$dmaSourceId dmaManualId=$manualUniqueId -s"|" @sqlcmdAuthArgs | findstr /v /c:"---" | Add-Content -Path $foldername\$tableList -Encoding utf8
}
# Pull perfmon file if we are running from same server.  Generate empty file if running on remote server
# Capability does not exist yet to run against remote computer

if ($ignorePerfmon -eq "true") {
    WriteLog -logLocation $foldername\$logFile -logMessage "Skipping Perfmon Information..."  -logOperation "FILE"
    if (($instancename -eq "MSSQLSERVER") -and ([string]$env:computername.toUpper() -ne [string]$machinename.toUpper())) {
        .\dmaSQLServerPerfmonDataset.ps1 -operation createemptyfile -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $manualUniqueId
    }
    else {
        .\dmaSQLServerPerfmonDataset.ps1 -operation createemptyfile -namedInstanceName $instancename -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $manualUniqueId
    }
}
else {
    WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving Perfmon Information..."  -logOperation "FILE"
    if (($instancename -eq "MSSQLSERVER") -and ([string]$env:computername.toUpper() -eq [string]$machinename.toUpper())) {
        .\dmaSQLServerPerfmonDataset.ps1 -operation collect -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $manualUniqueId
    }
    elseif (($instancename -ne "MSSQLSERVER") -and ([string]$env:computername.toUpper() -eq [string]$machinename.toUpper())) {
        .\dmaSQLServerPerfmonDataset.ps1 -operation collect -namedInstanceName $instancename -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $manualUniqueId
    }
    elseif (($instancename -eq "MSSQLSERVER") -and ([string]$env:computername.toUpper() -ne [string]$machinename.toUpper())) {
        .\dmaSQLServerPerfmonDataset.ps1 -operation createemptyfile -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $manualUniqueId
    }
    elseif (($instancename -ne "MSSQLSERVER") -and ([string]$env:computername.toUpper() -ne [string]$machinename.toUpper())) {
        .\dmaSQLServerPerfmonDataset.ps1 -operation createemptyfile -namedInstanceName $instancename -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $manualUniqueId
    }
}

<# Getting HW Specs. #>
if ($isCloudOrLinuxHost -eq "AZURE") {
    WriteLog -logLocation $foldername\$logFile -logMessage "Skipping SQL Server HW Shape Info for Machine $machinename ...Unavailable in AZURE SQL Managed Instance." -logOperation "BOTH"
    WriteLog -logLocation $foldername\$logFile -logMessage "     Writing Empty $computerSpecsFile file" -logOperation "BOTH"
    Set-Content -Path $foldername\$computerSpecsFile -Encoding utf8 -Value '"pkey"|"dma_source_id"|"dma_manual_id"|"MachineName"|"PhysicalCpuCount"|"LogicalCpuCount"|"TotalOSMemoryMB"'
}
elseif ($isCloudOrLinuxHost -eq "LINUX") {
    WriteLog -logLocation $foldername\$logFile -logMessage "Skipping SQL Server HW Shape Info for Machine $machinename ...Unavailable for Linux Host." -logOperation "BOTH"
    Set-Content -Path $foldername\$computerSpecsFile -Encoding utf8 -Value '"pkey"|"dma_source_id"|"dma_manual_id"|"MachineName"|"PhysicalCpuCount"|"LogicalCpuCount"|"TotalOSMemoryMB"'
}
else {
    WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving SQL Server HW Shape Info for Machine $machinename ..." -logOperation "BOTH"
    .\dmaSQLServerHWSpecs.ps1 -computerName $machinename -outputPath $foldername\$computerSpecsFile -logLocation $foldername\$logFile -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $manualUniqueId -requestCreds:$collectVMSpecs
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
    try {
        # Open the temporary file for writing using the specific UTF8-No-BOM encoding
        # This keeps only a small buffer of the file content in memory at any time.
        $writer = New-Object System.IO.StreamWriter -ArgumentList $tempFile, $false, $utf8NoBom

        # Read the content line by line (Get-Content is streaming by default when not using -Raw)
        $lines = Get-Content -Path $inputFile

        $firstLine = $true
        foreach ($line in $lines) {
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

        WriteLog -logLocation $foldername\$logFile -logMessage "          $($file.Name) successfully processed..." -logOperation "BOTH"
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
foreach ($file in Get-ChildItem -Path $foldername\*.csv, $foldername\*.log) {
    $inputFile = Split-Path -Leaf $file
    $errorContentCount = 0
    [regex]$pattern = "(Msg(\s\d*)(.)(\n|\s)Level(\s\d*.)(\n|\s)State(\s\d*)(.)(\n|\s))"
    $content = Get-Content -Path $foldername\$inputFile | select-string -Pattern $pattern
    if (![string]::IsNullOrEmpty($content)) {
        $errorContentCount = 1
    }
    else {
        $errorContentCount = 0
    }
    WriteLog -logLocation $foldername\$sqlErrorLogFile -logMessage "Checking for error messages within collection $inputFile ..." -logOperation "FILE"
    if ($errorContentCount -gt 0) {
        WriteLog -logLocation $foldername\$sqlErrorLogFile -logMessage "     Errors found within collection $inputFile ..." -logOperation "FILE"
    }
    $totalErrorCount = $totalErrorCount + $errorContentCount
}

WriteLog -logLocation $foldername\$logFile -logMessage "Checking for the presence of all required files..." -logOperation "BOTH"
foreach ($directory in $outputFileArray) {
    if (Test-Path -Path $PSScriptRoot\$foldername\$directory) {
        WriteLog -logLocation $foldername\$logFile -logMessage "  File $directory exists" -logOperation "FILE"
    }
    else {
        WriteLog -logLocation $foldername\$logFile -logMessage "  File $directory does not exist" -logOperation "BOTH"
		$totalErrorCount = $totalErrorCount + $errorContentCount
    }
}

if ($totalErrorCount -gt 0) {
    $zippedopfolder = $foldername + '_ERROR.zip'
}
else {
    $zippedopfolder = $foldername + '.zip'
}

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
