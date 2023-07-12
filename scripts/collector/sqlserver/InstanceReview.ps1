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
.EXAMPLE
    To use a specific username / password combination for a named instance:
        C:\InstanceReview.ps1 -serverName [server name / ip address]\[instance name] -collectionUserName [collection username] -collectionUserPass [collection username password]
    
    To use a specific username / password combination for a default instance:
        C:\InstanceReview.ps1 -serverName [server name / ip address] -collectionUserName [collection username] -collectionUserPass [collection username password]

.NOTES
    https://googlecloudplatform.github.io/database-assessment/
#>
Param(
[Parameter(Mandatory=$true)][string]$serverName = "",
[Parameter(Mandatory=$false)][string]$port="",
[Parameter(Mandatory=$false)][string]$database="all",
[Parameter(Mandatory=$false)][string]$collectionUserName = "",
[Parameter(Mandatory=$false)][string]$collectionUserPass = ""
)

$foldername = ""

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
        Write-Output "Retrieving Metadata Information from $serverName"
        $obj = sqlcmd -S $serverName -i sql\foldername.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -v database=$database | findstr /v /c:"---"
        if ([string]$database -ne "all") {
            $validDBObj = sqlcmd -S $serverName -i sql\checkValidDatabase.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -h-1 -v database=$database | findstr /v /c:"-"
            $countValidDBs = $validDBObj
            if (([string]::IsNullorEmpty($obj)) -or ([int]$countValidDBs -eq 0)) {
                Write-Output " "
                Write-Output "SQL Server Database $database not valid.  Exiting Script...."
                Exit 1                
            }
        }
    } else {
        $serverName = "$serverName,$port"
        Write-Output "Retrieving Metadata Information from $serverName"
        $obj = sqlcmd -S $serverName -i sql\foldername.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -v database=$database | findstr /v /c:"---"
        if ([string]$database -ne "all") {
            $validDBObj = sqlcmd -S $serverName -i sql\checkValidDatabase.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -h-1 -v database=$database | findstr /v /c:"-"
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

$op_version = "4.3.9"

$foldername = 'opdb' + '_' + 'mssql' + '_' + 'PerfCounter' + '__' + $dbversion + '_' + $op_version + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts

$folderLength = ($PSScriptRoot + '\' + $foldername).Length
if ($folderLength -le 260) {
    Write-Output "Creating directory $foldername"
    $null = New-Item -Name $foldername -ItemType Directory
} else {
    Write-Output "Folder length exceeds 260 characters.  Run collection tool from a path with less characters"
    Write-Output "Folder being created is: $PSScriptRoot\$foldername"
    Exit 1
}

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

$outputFileArray = @($compFileName, $srvFileName, $blockingFeatures, $linkedServers, $dbsizes, $dbClusterNodes, $objectList, $tableList, $indexList, $columnDatatypes, $userConnectionList, $perfMonOutput, $dbccTraceFlg, $diskVolumeInfo, $dbServerFlags)

Write-Output "Checking max directory path lengths for errors..."
foreach ($directory in $outputFileArray) {
	$folderLength = ($PSScriptRoot + '\' + $foldername + '\' + $directory).Length
    if ($folderLength -gt 260) {
        Write-Output "Output file $PSScriptRoot\$foldername\$directory name exceeds 260 characters."
        Write-Output "Execute collection from a path with less characters"
        Exit 1
    }
}

Write-Output "Retriving SQL Server Installed Components..."
sqlcmd -S $serverName -i sql\componentsInstalled.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$compFileName
Write-Output "Retriving SQL Server Properties..."
sqlcmd -S $serverName -i sql\serverProperties.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$srvFileName
sqlcmd -S $serverName -i sql\dbServerUnsupportedFlags.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$dbServerFlags
Write-Output "Retriving SQL Server Features..."
sqlcmd -S $serverName -i sql\features.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$blockingFeatures
Write-Output "Retriving SQL Server Linked Servers..."
sqlcmd -S $serverName -i sql\linkedServers.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$linkedServers
Write-Output "Retriving SQL Server Database Sizes..."
sqlcmd -S $serverName -i sql\dbSizes.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -v pkey=$pkey database=$database -s"|" | findstr /v /c:"---" > $foldername\$dbsizes
Write-Output "Retriving SQL Server Cluster Nodes..."
sqlcmd -S $serverName -i sql\dbClusterNodes.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$dbClusterNodes
Write-Output "Retriving SQL Server Object Info..."
sqlcmd -S $serverName -i sql\objectList.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -v pkey=$pkey database=$database -s"|" | findstr /v /c:"---" > $foldername\$objectList
sqlcmd -S $serverName -i sql\tableList.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -v pkey=$pkey database=$database -s"|" | findstr /v /c:"---" > $foldername\$tableList
sqlcmd -S $serverName -i sql\indexList.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -v pkey=$pkey database=$database -s"|" | findstr /v /c:"---" > $foldername\$indexList
sqlcmd -S $serverName -i sql\columnDatatypes.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -v pkey=$pkey database=$database -s"|" | findstr /v /c:"---" > $foldername\$columnDatatypes
sqlcmd -S $serverName -i sql\userConnectionInfo.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -v pkey=$pkey database=$database -s"|" | findstr /v /c:"---" > $foldername\$userConnectionList
sqlcmd -S $serverName -i sql\dbccTraceFlags.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$dbccTraceFlg
sqlcmd -S $serverName -i sql\diskVolumeInfo.sql -U $collectionUserName -P $collectionUserPass -W -m 1 -u -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$diskVolumeInfo

Write-Output "Retrieving OS Disk Cluster Information.."
if (Test-Path -Path $env:TEMP\tempDisk.csv) {
    Remove-Item -Path $env:TEMP\tempDisk.csv
}

Add-Content -Path $env:TEMP\tempDisk.csv -Value "PKEY|volume_mount_point|file_system_type|logical_volume_name|total_size_gb|available_size_gb|space_free_pct|cluster_block_size" -Encoding utf8

# If we are running against a remote computer, we need to create an empty tempDisk.csv file
if ([string]$env:computername.toUpper() -eq [string]$machinename.toUpper()) {
    foreach($drive in (Import-Csv -Delimiter '|' -Path $foldername\*DiskVolInfo*.csv | Select-Object -Property volume_mount_point).volume_mount_point) {
        $blocksize = (Get-CimInstance -ClassName Win32_Volume | Select-Object Name, Label, BlockSize, FileSystem | `
        Where-Object {($_.Name -Contains $drive) -and ($_.FileSystem -in 'NTFS')} | Select-Object -Property BlockSize).BlockSize
        Get-Content -Path  $foldername\*DiskVolInfo*.csv | ForEach-Object {			
            if ($_ -match ([regex]::Escape($drive))) {
                if ([int]$blocksize -gt 0)
                {
                    $blockValue = $_ + '|' +$blocksize
                    Add-Content -Path $env:TEMP\tempDisk.csv -Value $blockValue -Encoding utf8
                }
                else
                {
                    $blockValue = $_ + '|null'
                    Add-Content -Path $env:TEMP\tempDisk.csv -Value $blockValue -Encoding utf8
                }
            }
        } 
    }
}

foreach($file in Get-ChildItem -Path $foldername\*DiskVolInfo*.csv) {
    $outputFileName=$file.name
    Get-Content -Path $env:TEMP\tempDisk.csv | Set-Content -Encoding utf8 -Path $foldername\$outputFileName
}

# Pull perfmon file if we are running from same server.  Generate empty file if running on remote server
# Capability does not exist yet to run against remote computer
if (($instancename -eq "MSSQLSERVER") -and ([string]$env:computername.toUpper() -eq [string]$machinename.toUpper())) {
    .\dma_sqlserver_perfmon_dataset.ps1 -operation collect -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey
} elseif (($instancename -ne "MSSQLSERVER") -and ([string]$env:computername.toUpper() -eq [string]$machinename.toUpper())) {
    .\dma_sqlserver_perfmon_dataset.ps1 -operation collect -managedInstanceName $instancename -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey
} elseif (($instancename -eq "MSSQLSERVER") -and ([string]$env:computername.toUpper() -ne [string]$machinename.toUpper())) {
    .\dma_sqlserver_perfmon_dataset.ps1 -operation createemptyfile -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey
} elseif (($instancename -ne "MSSQLSERVER") -and ([string]$env:computername.toUpper() -ne [string]$machinename.toUpper())) {
    .\dma_sqlserver_perfmon_dataset.ps1 -operation createemptyfile -managedInstanceName $instancename -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput -pkey $pkey
}

Write-Output "Remove special characters from extracted Files.."
foreach($file in Get-ChildItem -Path $foldername\*.csv) {
    (Get-Content $file -Raw).Replace("`r`n","`n") | Set-Content $file -Encoding utf8 -Force
}
$zippedopfolder = $foldername + '.zip'
Write-Output "Zipping Output to $zippedopfolder"

$powerShellVersion = $PSVersionTable.PSVersion.Major

if ($powerShellVersion -ge 5) {
    Compress-Archive -Path $foldername\*.csv -DestinationPath $zippedopfolder

    if (Test-Path -Path $zippedopfolder) {
        Write-Output "Removing directory $foldername"
        Remove-Item -Path $foldername -Recurse -Force
    }
    if (Test-Path -Path $env:TEMP\tempDisk.csv) {
        Write-Output "Clean up Temp File area"
        Remove-Item -Path $env:TEMP\tempDisk.csv
    }

    Write-Output ""
    Write-Output ""
    Write-Output "Return file $PSScriptRoot\$zippedopfolder"
    Write-Output "to Google to complete assessment"
} else {
    Write-Output ""
    Write-Output ""
    Write-Output "Please manually zip the files in $foldername and return to Google to complete assessment"
}

Exit 0