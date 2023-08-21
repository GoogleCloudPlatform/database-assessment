# Copyright 2023 Google LLC
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
    Connection port (default:1433)
.PARAMETER database
    Run assessment for a single database (default:all)
.PARAMETER collectionUserName
    Collection username (optional)
.PARAMETER collectionUserPass
    Collection username password (optional)
.PARAMETER ignorePerfmon
    Signals if the perfmon collection should be skipped (default:false) 
.EXAMPLE
    To use a specific username / password combination for a named instance:
        C:\instanceReview.ps1 -serverName [server name / ip address]\[instance name] -collectionUserName [collection username] -collectionUserPass [collection username password]
    
    To use a specific username / password combination for a default instance:
        C:\instanceReview.ps1 -serverName [server name / ip address] -collectionUserName [collection username] -collectionUserPass [collection username password]

.NOTES
    https://googlecloudplatform.github.io/database-assessment/
#>
Param(
[Parameter(Mandatory=$true)][string]$serverName = "",
[Parameter(Mandatory=$false)][string]$port="",
[Parameter(Mandatory=$false)][string]$database="all",
[Parameter(Mandatory=$false)][string]$collectionUserName = "",
[Parameter(Mandatory=$false)][string]$collectionUserPass = "",
[Parameter(Mandatory=$false)][string]$ignorePerfmon = "false"
)

Import-Module $PSScriptRoot\dmaCollectorCommonFunctions.psm1

$powerShellVersion = $PSVersionTable.PSVersion.Major
$foldername = ""
$errorCount = 0

if ([string]::IsNullorEmpty($serverName)) {
    Write-Output "Server parameter $serverName is empty.  Ensure that the parameter is provided"
    Exit 1
} elseif ([string]::IsNullorEmpty($collectionUserName)) {
    Write-Output "Collection Username parameter $collectionUserName is empty.  Ensure that the parameter is provided"
    Exit 1
} elseif ([string]::IsNullorEmpty($collectionUserPass)) {
    Write-Output "Collection Username password parameter $collectionUserPass is empty.  Ensure that the parameter is provided"
    Exit 1
} else {
    if ([string]::IsNullorEmpty($port)) {
        WriteLog -logMessage "Retrieving Metadata Information from $serverName" -logOperation "MESSAGE"
        $inputServerName = $serverName
        $obj = sqlcmd -S $serverName -i sql\foldername.sql -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -v database=$database | findstr /v /c:"---"
        $dbNameArray = @(sqlcmd -S $serverName -i sql\getDBList.sql -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -h-1 -v database=$database)
        $dmaSourceId = @(sqlcmd -S $serverName -i sql\getDmaSourceId.sql -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -h-1)
        if ([string]$database -ne "all") {
            $validDBObj = sqlcmd -S $serverName -i sql\checkValidDatabase.sql -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -h-1 -v database=$database | findstr /v /c:"-"
            $countValidDBs = $validDBObj
            if (([string]::IsNullorEmpty($obj)) -or ([int]$countValidDBs -eq 0)) {
                Write-Output " "
                Write-Output "SQL Server Database $database not valid.  Exiting Script...."
                Exit 1                
            }
        }
    } else {
        $inputServerName = $serverName
        $serverName = "$serverName,$port"
        WriteLog -logMessage "Retrieving Metadata Information from $serverName" -logOperation "MESSAGE"
        $obj = sqlcmd -S $serverName -i sql\foldername.sql -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -v database=$database | findstr /v /c:"---"
        $dbNameArray = @(sqlcmd -S $serverName -i sql\getDBList.sql -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -h-1 -v database=$database)
        $dmaSourceId = @(sqlcmd -S $serverName -i sql\getDmaSourceId.sql -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -h-1)
        if ([string]$database -ne "all") {
            $validDBObj = sqlcmd -S $serverName -i sql\checkValidDatabase.sql -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -h-1 -v database=$database | findstr /v /c:"-"
            $countValidDBs = $validDBObj
            if (([string]::IsNullorEmpty($obj)) -or ([int]$countValidDBs -eq 0)) {
                Write-Output " "
                Write-Output "SQL Server Database $database not valid.  Exiting Script...."
                Exit 1                
            }
        }
    }
}

if ([string]::IsNullorEmpty($obj)) {
    Write-Output " "
    Write-Output "Connection Error to SQL Server $serverName.  Exiting Script...."
    Exit 1
}

$splitobj = $obj[1].Split('')
$values = $splitobj | ForEach-Object { if($_.Trim() -ne '') { $_ } }

$dbversion = $values[0].Replace('.','')
$machinename = $values[1]
if ([string]$database -eq "all") {
    $dbname = $values[2]
} else {
    $dbname = $database
}
$instancename = $values[3]
$current_ts = $values[4]
$pkey = $values[5]
$dmaSourceId = $dmaSourceId[0]

$op_version = "4.3.14"

if ($ignorePerfmon -eq "true") {
    $perfCounterLabel = "NoPerfCounter"
} else {
    $perfCounterLabel = "PerfCounter"
}

$foldername = 'opdb' + '_' + 'mssql' + '_' + $perfCounterLabel + '__' + $dbversion + '_' + $op_version + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts
$logFile = 'opdb_mssql_collectorLog' + '__' + $dbversion + '_' + $op_version + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.log'
$sqlErrorLogFile = 'opdb_mssql_sqlErrorlog' + '__' + $dbversion + '_' + $op_version + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.log'

$folderLength = ($PSScriptRoot + '\' + $foldername).Length
if ($folderLength -le 260) {
    WriteLog -logMessage "Creating directory $PSScriptRoot\$foldername" -logOperation "MESSAGE"
    Write-Output " "
    $null = New-Item -Name $foldername -ItemType Directory
} else {
    WriteLog -logMessage "Folder length exceeds 260 characters.  Run collection tool from a path with less characters" -logOperation "MESSAGE"
    WriteLog -logMessage "Folder being created is: $PSScriptRoot\$foldername" -logOperation "MESSAGE"
    Write-Output " "
    Write-Host "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) Consider shortening foldername by reducing 'db-migration-assessment-collection-scripts-sqlserver' to 'google-dma'" -ForegroundColor red
    Exit 1
}

$logFileArray = @($logFile, $sqlErrorLogFile)

WriteLog -logMessage "Checking directory path + log file name lengths for max length limitations..." -logOperation "MESSAGE"
foreach ($logFileName in $logFileArray) {
	$folderLength = ($PSScriptRoot + '\' + $foldername + '\' + $logFileName).Length
    if ($folderLength -gt 260) {
        WriteLog -logMessage "Output file $PSScriptRoot\$foldername\$logFileName name exceeds 260 characters." -logOperation "MESSAGE"
        Write-Output " "
        Write-Host "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) Execute collection from a path with less than 260 characters." -ForegroundColor red
        Write-Host "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) Consider shortening foldername by reducing 'db-migration-assessment-collection-scripts-sqlserver' to 'google-dma'" -ForegroundColor red
        Exit 1
    }
}

WriteLog -logLocation $foldername\$logFile -logMessage "PS Version Table" -logOperation "FILE"
$PSVersionTable | out-string | Add-Content -Encoding utf8 -Path $foldername\$logFile

WriteLog -logLocation $foldername\$logFile -logMessage "Output Encoding Table" -logOperation "FILE"
$OutputEncoding | out-string | Add-Content -Encoding utf8 -Path $foldername\$logFile

WriteLog -logLocation $foldername\$logFile -logMessage "DMA Source Id: $dmaSourceId " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "FILE"

WriteLog -logLocation $foldername\$logFile -logMessage "Execution Variables List" -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "serverName = $inputServerName " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "port = $port " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "database = $database " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "collectionUserName = $collectionUserName " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "ignorePerfmon = $ignorePerfmon " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage "connectionString = $serverName " -logOperation "FILE"
WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "FILE"


$compFileName = 'opdb' + '__' + 'CompInstalled' + '__' + $dbversion + '_' + $op_version + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
$srvFileName = 'opdb' + '__' + 'ServerProps' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
$blockingFeatures = 'opdb' + '__' + 'BlockFeatures' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
$linkedServers = 'opdb' + '__' + 'LinkedSrvrs' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
$dbsizes = 'opdb' + '__' + 'DbSizes' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
$dbClusterNodes = 'opdb' + '__' + 'DbClusterNodes' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
$objectList = 'opdb' + '__' + 'ObjectList' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
$tableList = 'opdb' + '__' + 'TableList' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
$indexList = 'opdb' + '__' + 'IndexList' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
$columnDatatypes = 'opdb' + '__' + 'ColumnDatatypes' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
$userConnectionList = 'opdb' + '__' + 'UserConnections' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
$perfMonOutput = 'opdb' + '__' + 'PerfMonData' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
$dbccTraceFlg = 'opdb' + '__' + 'DbccTrace' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
$diskVolumeInfo = 'opdb' + '__' + 'DiskVolInfo' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
$dbServerFlags = 'opdb' + '__' + 'DbServerFlags' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
$manifestFile = 'opdb' + '__' + 'manifest' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.txt'

$outputFileArray = @($compFileName, $srvFileName, $blockingFeatures, $linkedServers, $dbsizes, $dbClusterNodes, $objectList, $tableList, $indexList, $columnDatatypes, $userConnectionList, $perfMonOutput, $dbccTraceFlg, $diskVolumeInfo, $dbServerFlags)

WriteLog -logMessage "Checking directory path + output file name lengths for max length limitations..." -logOperation "MESSAGE"
foreach ($directory in $outputFileArray) {
	$folderLength = ($PSScriptRoot + '\' + $foldername + '\' + $directory).Length
    if ($folderLength -gt 260) {
        WriteLog -logMessage "Output file $PSScriptRoot\$foldername\$directory name exceeds 260 characters." -logOperation "MESSAGE"
        Write-Output " "
        WriteLog -logMessage "Execute collection from a path with less than 260 characters." -logOperation "MESSAGE"
        Write-Host "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) Execute collection from a path with less than 260 characters." -ForegroundColor red
        Write-Host "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) Consider shortening foldername by reducing 'db-migration-assessment-collection-scripts-sqlserver' to 'google-dma'" -ForegroundColor red
        Exit 1
    }
}

WriteLog -logLocation $foldername\$logFile -logMessage "Executing Assessment on Server $serverName Against the Following Databases:" -logOperation "BOTH"
foreach ($dbNameList in $dbNameArray) {
    WriteLog -logLocation $foldername\$logFile -logMessage "            $dbNameList" -logOperation "BOTH"
}

WriteLog -logLocation $foldername\$logFile -logMessage "Retriving SQL Server Installed Components..." -logOperation "BOTH"
    sqlcmd -S $serverName -i sql\componentsInstalled.sql -d master -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -v pkey=$pkey dmaSourceId=$dmaSourceId -s"|" | findstr /v /c:"---" > $foldername\$compFileName

WriteLog -logLocation $foldername\$logFile -logMessage "Retriving SQL Server Properties..." -logOperation "BOTH"
    sqlcmd -S $serverName -i sql\serverProperties.sql -d master -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -v pkey=$pkey dmaSourceId=$dmaSourceId -s"|" | findstr /v /c:"---" > $foldername\$srvFileName

WriteLog -logLocation $foldername\$logFile -logMessage "Retriving SQL Server CloudSQL Unsupported Flag Info..." -logOperation "BOTH"
    sqlcmd -S $serverName -i sql\dbServerUnsupportedFlags.sql -d master -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -v pkey=$pkey dmaSourceId=$dmaSourceId -s"|" | findstr /v /c:"---" > $foldername\$dbServerFlags

WriteLog -logLocation $foldername\$logFile -logMessage "Retriving SQL Server Features in Use Info..." -logOperation "BOTH"
    sqlcmd -S $serverName -i sql\dbServerFeatures.sql -d master -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -v pkey=$pkey dmaSourceId=$dmaSourceId -s"|" | findstr /v /c:"---" > $foldername\$blockingFeatures

WriteLog -logLocation $foldername\$logFile -logMessage "Retriving SQL Server Linked Server Info..." -logOperation "BOTH"
    sqlcmd -S $serverName -i sql\linkedServers.sql -d master -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -v pkey=$pkey dmaSourceId=$dmaSourceId -s"|" | findstr /v /c:"---" > $foldername\$linkedServers

WriteLog -logLocation $foldername\$logFile -logMessage "Retriving SQL Server Cluster Node Info..." -logOperation "BOTH"
    sqlcmd -S $serverName -i sql\dbClusterNodes.sql -d master -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -v pkey=$pkey dmaSourceId=$dmaSourceId -s"|" | findstr /v /c:"---" > $foldername\$dbClusterNodes

WriteLog -logLocation $foldername\$logFile -logMessage "Retriving SQL Server DBCC Trace Info..." -logOperation "BOTH"
    sqlcmd -S $serverName -i sql\dbccTraceFlags.sql -d master -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -v pkey=$pkey dmaSourceId=$dmaSourceId -s"|" | findstr /v /c:"---" > $foldername\$dbccTraceFlg

WriteLog -logLocation $foldername\$logFile -logMessage "Retriving SQL Server Disk Volume Info..." -logOperation "BOTH"
    sqlcmd -S $serverName -i sql\diskVolumeInfo.sql -d master -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -v pkey=$pkey dmaSourceId=$dmaSourceId -s"|" | findstr /v /c:"---" > $foldername\$diskVolumeInfo

### First establish headers for the collection files which could execute against multiple databases in the instance
Set-Content -Path $foldername\$objectList -Encoding utf8 -Value "PKEY|database_name|schema_name|object_name|object_type|object_type_desc|object_count|lines_of_code|associated_table_name|dma_source_id"
Set-Content -Path $foldername\$tableList -Encoding utf8 -Value "PKEY|database_name|schema_name|table_name|partition_count|is_memory_optimized|temporal_type|is_external|lock_escalation|is_tracked_by_cdc|text_in_row_limit|is_replicated|row_count|data_compression|total_space_mb|used_space_mb|unused_space_mb|dma_source_id"
Set-Content -Path $foldername\$indexList -Encoding utf8 -Value "PKEY|database_name|schema_name|table_name|index_name|index_type|is_primary_key|is_unique|fill_factor|allow_page_locks|has_filter|data_compression|data_compression_desc|is_partitioned|count_key_ordinal|count_partition_ordinal|count_is_included_column|total_space_mb|dma_source_id"
Set-Content -Path $foldername\$columnDatatypes -Encoding utf8 -Value "PKEY|database_name|schema_name|table_name|datatype|max_length|precision|scale|is_computed|is_filestream|is_masked|encryption_type|is_sparse|rule_object_id|column_count|dma_source_id"
Set-Content -Path $foldername\$userConnectionList -Encoding utf8 -Value "PKEY|database_name|is_user_process|host_name|program_name|login_name|num_reads|num_writes|last_read|last_write|reads|logical_reads|writes|client_interface_name|nt_domain|nt_user_name|client_net_address|local_net_address|dma_source_id"
Set-Content -Path $foldername\$dbsizes -Encoding utf8 -Value "PKEY|database_name|type_desc|current_size_mb|dma_source_id"

### Iterate through collections that could execute against multiple databases in the instance
foreach ($databaseName in $dbNameArray) {
    WriteLog -logLocation $foldername\$logFile -logMessage "Retriving SQL Server Object Info for Database $databaseName ..." -logOperation "BOTH"
        sqlcmd -S $serverName -i sql\objectList.sql -d $databaseName -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -h-1 -v pkey=$pkey database=$databaseName dmaSourceId=$dmaSourceId -s"|" | findstr /v /c:"---" | Add-Content -Path $foldername\$objectList -Encoding utf8

    WriteLog -logLocation $foldername\$logFile -logMessage "Retriving SQL Server Table Info for Database $databaseName ..." -logOperation "BOTH"
        sqlcmd -S $serverName -i sql\tableList.sql -d $databaseName -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -h-1 -v pkey=$pkey database=$databaseName dmaSourceId=$dmaSourceId -s"|" | findstr /v /c:"---" | Add-Content -Path $foldername\$tableList -Encoding utf8

    WriteLog -logLocation $foldername\$logFile -logMessage "Retriving SQL Server Index Info for Database $databaseName ..." -logOperation "BOTH"
        sqlcmd -S $serverName -i sql\indexList.sql -d $databaseName -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -h-1 -v pkey=$pkey database=$databaseName dmaSourceId=$dmaSourceId -s"|" | findstr /v /c:"---" | Add-Content -Path $foldername\$indexList -Encoding utf8

    WriteLog -logLocation $foldername\$logFile -logMessage "Retriving SQL Server Column Datatype Info for Database $databaseName ..." -logOperation "BOTH"
        sqlcmd -S $serverName -i sql\columnDatatypes.sql -d $databaseName -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -h-1 -v pkey=$pkey database=$databaseName dmaSourceId=$dmaSourceId -s"|" | findstr /v /c:"---" | Add-Content -Path $foldername\$columnDatatypes -Encoding utf8

    WriteLog -logLocation $foldername\$logFile -logMessage "Retriving SQL Server User Connection Info for Database $databaseName ..." -logOperation "BOTH"
        sqlcmd -S $serverName -i sql\userConnectionInfo.sql -d $databaseName -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -h-1 -v pkey=$pkey database=$databaseName dmaSourceId=$dmaSourceId -s"|" | findstr /v /c:"---" | Add-Content -Path $foldername\$userConnectionList -Encoding utf8

    WriteLog -logLocation $foldername\$logFile -logMessage "Retriving SQL Server Database Size Info for Database $databaseName ..." -logOperation "BOTH"
        sqlcmd -S $serverName -i sql\dbSizes.sql -d $databaseName -U $collectionUserName -P $collectionUserPass -l 30 -W -m 1 -u -h-1 -v pkey=$pkey database=$databaseName dmaSourceId=$dmaSourceId -s"|" | findstr /v /c:"---" | Add-Content -Path $foldername\$dbsizes -Encoding utf8
}

# Pull perfmon file if we are running from same server.  Generate empty file if running on remote server
# Capability does not exist yet to run against remote computer

if ($ignorePerfmon -eq "true") {
    WriteLog -logLocation $foldername\$logFile -logMessage "Skipping Perfmon Information..."  -logOperation "FILE"
    if (($instancename -eq "MSSQLSERVER") -and ([string]$env:computername.toUpper() -ne [string]$machinename.toUpper())) {
        .\dmaSQLServerPerfmonDataset.ps1 -operation createemptyfile -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId
    } else {
        .\dmaSQLServerPerfmonDataset.ps1 -operation createemptyfile -managedInstanceName $instancename -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId
    }
} else {
    WriteLog -logLocation $foldername\$logFile -logMessage "Retrieving Perfmon Information..."  -logOperation "FILE"
    if (($instancename -eq "MSSQLSERVER") -and ([string]$env:computername.toUpper() -eq [string]$machinename.toUpper())) {
        .\dmaSQLServerPerfmonDataset.ps1 -operation collect -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId
    } elseif (($instancename -ne "MSSQLSERVER") -and ([string]$env:computername.toUpper() -eq [string]$machinename.toUpper())) {
        .\dmaSQLServerPerfmonDataset.ps1 -operation collect -managedInstanceName $instancename -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId
    } elseif (($instancename -eq "MSSQLSERVER") -and ([string]$env:computername.toUpper() -ne [string]$machinename.toUpper())) {
        .\dmaSQLServerPerfmonDataset.ps1 -operation createemptyfile -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId
    } elseif (($instancename -ne "MSSQLSERVER") -and ([string]$env:computername.toUpper() -ne [string]$machinename.toUpper())) {
        .\dmaSQLServerPerfmonDataset.ps1 -operation createemptyfile -managedInstanceName $instancename -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey -dmaSourceId $dmaSourceId
    }
}

WriteLog -logLocation $foldername\$logFile -logMessage "Remove special characters and UTF8 BOM from extracted files..." -logOperation "BOTH"
foreach($file in Get-ChildItem -Path $foldername\*.csv) {
	$inputFile = Split-Path -Leaf $file
	#((Get-Content -Path $foldername\$inputFile) -join "`n") + "`n" | Set-Content -NoNewLine -Encoding utf8 -Force -Path $foldername\$inputFile
    ((Get-Content -Path $foldername\$inputFile) -join "`n") + "`n" | Set-Content -Encoding utf8 -Force -Path $foldername\$inputFile
	$utf8 = New-Object System.Text.UTF8Encoding $false
	$fileContent = Get-Content $foldername\$inputFile -Raw
	Set-Content -Value $utf8.GetBytes($fileContent) -Encoding Byte -Path $foldername\$inputFile -Force
}

WriteLog -logLocation $foldername\$logFile -logMessage "Creating the manifest..." -logOperation "BOTH"
foreach($file in Get-ChildItem -Path $foldername\*.csv) {
	$inputFile = Split-Path -Leaf $file
    createManifestFile -manifestFileLocation $foldername -manifestOutputFileName $manifestFile -manifestedFileName $inputFile
}

WriteLog -logLocation $foldername\$logFile -logMessage "Checking for error messages within collection files..." -logOperation "BOTH"
foreach($file in Get-ChildItem -Path $foldername\*.csv, $foldername\*.log) {
	$inputFile = Split-Path -Leaf $file
    [regex]$pattern = "(Msg(\s\d*)(.)(\n|\s)Level(\s\d*.)(\n|\s)State(\s\d*)(.)(\n|\s))"
    $content = Get-Content -Path $foldername\$inputFile | select-string -Pattern $pattern
    WriteLog -logLocation $foldername\$sqlErrorLogFile -logMessage "Checking for error messages within collection $inputFile ..." -logOperation "FILE"
    if ($errorCount -gt ($errorCount + $content.length)) {
        WriteLog -logLocation $foldername\$sqlErrorLogFile -logMessage "Errors found within collection $inputFile ..." -logOperation "FILE"
    }
    $errorCount = $errorCount + $content.length
}

if ($errorCount -gt 0) {
    $zippedopfolder = $foldername + '_ERROR.zip'
} else {
    $zippedopfolder = $foldername + '.zip'
}

WriteLog -logLocation $foldername\$logFile -logMessage "Zipping Output to $zippedopfolder..." -logOperation "BOTH"

if ($powerShellVersion -ge 5) {
    Compress-Archive -Path $foldername\*.csv,$foldername\*.log,$foldername\*.txt -DestinationPath $zippedopfolder

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
    WriteLog -logLocation $foldername\$logFile -logMessage "Return file $PSScriptRoot\$zippedopfolder" -logOperation "MESSAGE"
    WriteLog -logLocation $foldername\$logFile -logMessage "to Google to complete assessment" -logOperation "MESSAGE"
    WriteLog -logLocation $foldername\$logFile -logMessage "Collection Complete..." -logOperation "MESSAGE"
} else {
    WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "MESSAGE"
    WriteLog -logLocation $foldername\$logFile -logMessage " " -logOperation "MESSAGE"
    WriteLog -logLocation $foldername\$logFile -logMessage "Please manually zip the files in $foldername and" -logOperation "MESSAGE"
    WriteLog -logLocation $foldername\$logFile -logMessage "return to Google to complete assessment" -logOperation "MESSAGE"
    WriteLog -logLocation $foldername\$logFile -logMessage "Collection Complete..." -logOperation "MESSAGE"
}

Exit 0