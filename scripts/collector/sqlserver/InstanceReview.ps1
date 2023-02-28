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

    $op_version = (((Select-String -Path "..\..\..\.bumpversion.cfg" -SimpleMatch "current_version =").Line).split("=",2)[1]).trim()

    $foldername = 'opdb' + '_' + 'sqlsrv' + '_' + 'PerfCounter' + '__' + $dbversion + '_' + $op_version + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts

	Write-Output "Creating directory $foldername"
    $null = New-Item -Name $foldername -ItemType Directory

    $compFileName = 'opdb' + '__' + 'CompInstalled' + '__' + $dbversion + '_' + $op_version + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
    $srvFileName = 'opdb' + '__' + 'ServerProps' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
    $blockingFeatures = 'opdb' + '__' + 'BlockFeatures' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
    $linkedServers = 'opdb' + '__' + 'LinkedSrvrs' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
    $perfMonOutput = 'opdb' + '__' + 'PerfMonData' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'

	Write-Output "Retriving SQL Server Installed Components..."
	sqlcmd -S $sqlsrv -i sql\ComponentsInstalled.sql -U $user -P $pass -s"|" | findstr /v /c:"---" > $foldername\$compFileName
	Write-Output "Retriving SQL Server Properties..."
	sqlcmd -S $sqlsrv -i sql\ServerProperties.sql -U $user -P $pass -s"|" | findstr /v /c:"---" > $foldername\$srvFileName
	Write-Output "Retriving SQL Server Features..."
	sqlcmd -S $sqlsrv -i sql\Features.sql -U $user -P $pass -m 1 -s"|" | findstr /v /c:"---" > $foldername\$blockingFeatures
	Write-Output "Retriving SQL Server Linked Servers..."
	sqlcmd -S $sqlsrv -i sql\LinkedServers.sql -U $user -P $pass -m 1 -s"|" | findstr /v /c:"---" > $foldername\$linkedServers

	if ($instancename -eq "MSSQLSERVER") {
		.\dma_sqlserver_perfmon_dataset.ps1 -operation collect -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput
	} else {
		.\dma_sqlserver_perfmon_dataset.ps1 -operation collect -mssqlInstanceName $instancename -perfmonOutDir $foldername -perfmonOutFile $perfMonOutput
	}

    $zippedopfolder = $foldername + '.zip'
	Write-Output "Zipping Output to $zippedopfolder"
    Compress-Archive -Path $foldername\*.csv -DestinationPath $zippedopfolder
    Remove-Item -Path $foldername -Recurse -Force
}