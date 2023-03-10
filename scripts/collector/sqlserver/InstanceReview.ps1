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

Param(
[string]$user = "userfordma",
[string]$pass = "P@ssword135"
)

$objs = Import-Csv -Delimiter "," sqlsrv.csv
$foldername = ""
foreach($item in $objs) {
    $sqlsrv = $item.InstanceName
	Write-Output "Retrieving Metadata Information from $sqlsrv"
    $obj = sqlcmd -S $sqlsrv -i sql\foldername.sql -U $user -P $pass | findstr /v /c:"---"
    $splitobj = $obj[1].Split('')
    $values = $splitobj | ForEach-Object { if($_.Trim() -ne '') { $_ } }

    $dbversion = $values[0].Replace('.','')
    $machinename = $values[1]
    $dbname = $values[2]
    $instancename = $values[3]
    $current_ts = $values[4]
    $pkey = $values[5]

    $op_version = (((Select-String -Path "..\..\..\.bumpversion.cfg" -SimpleMatch "current_version =").Line).split("=",2)[1]).trim()

    $foldername = 'opdb' + '_' + 'sqlsrv' + '_' + 'PerfCounter' + '__' + $dbversion + '_' + $op_version + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts

    $folderLength = ($PSScriptRoot + '\' + $foldername).Length
    if ($folderLength -le 260) {
        Write-Output "Creating directory $foldername"
        $null = New-Item -Name $foldername -ItemType Directory
    } else {
        Write-Output "Folder length exceeds 260 characters.  Run collection tool from a"
        Write-Output "Folder being created is: $PSScriptRoot\$foldername"
        Exit
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

	Write-Output "Retriving SQL Server Installed Components..."
	sqlcmd -S $sqlsrv -i sql\componentsInstalled.sql -U $user -P $pass -W -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$compFileName
	Write-Output "Retriving SQL Server Properties..."
	sqlcmd -S $sqlsrv -i sql\serverProperties.sql -U $user -P $pass -W -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$srvFileName
	Write-Output "Retriving SQL Server Features..."
	sqlcmd -S $sqlsrv -i sql\features.sql -U $user -P $pass -W -m 1 -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$blockingFeatures
	Write-Output "Retriving SQL Server Linked Servers..."
	sqlcmd -S $sqlsrv -i sql\linkedServers.sql -U $user -P $pass -W -m 1 -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$linkedServers
	Write-Output "Retriving SQL Server Database Sizes..."
	sqlcmd -S $sqlsrv -i sql\dbSizes.sql -U $user -P $pass -W -m 1 -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$dbsizes
	Write-Output "Retriving SQL Server Cluster Nodes..."
	sqlcmd -S $sqlsrv -i sql\dbClusterNodes.sql -U $user -P $pass -W -m 1 -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$dbClusterNodes
	Write-Output "Retriving SQL Server Object Info..."
	sqlcmd -S $sqlsrv -i sql\objectList.sql -U $user -P $pass -W -m 1 -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$objectList
	sqlcmd -S $sqlsrv -i sql\tableList.sql -U $user -P $pass -W -m 1 -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$tableList
    sqlcmd -S $sqlsrv -i sql\indexList.sql -U $user -P $pass -W -m 1 -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$indexList
	sqlcmd -S $sqlsrv -i sql\columnDatatypes.sql -U $user -P $pass -W -m 1 -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$columnDatatypes
	sqlcmd -S $sqlsrv -i sql\userConnectionInfo.sql -U $user -P $pass -W -m 1 -v pkey=$pkey -s"|" | findstr /v /c:"---" > $foldername\$userConnectionList


	if ($instancename -eq "MSSQLSERVER") {
		.\dma_sqlserver_perfmon_dataset.ps1 -operation collect -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput
	} else {
		.\dma_sqlserver_perfmon_dataset.ps1 -operation collect -mssqlInstanceName $instancename -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput
	}

    $zippedopfolder = $foldername + '.zip'
	Write-Output "Zipping Output to $zippedopfolder"
    Compress-Archive -Path $foldername\*.csv -DestinationPath $zippedopfolder
    if (Test-Path -Path $zippedopfolder) {
		Write-Output "Removing directory $foldername"
        Remove-Item -Path $foldername -Recurse -Force
    }

    Write-Output ""
    Write-Output ""
    Write-Output "Return file $PSScriptRoot\$zippedopfolder"
    Write-Output "to Google to complete assessment"
}