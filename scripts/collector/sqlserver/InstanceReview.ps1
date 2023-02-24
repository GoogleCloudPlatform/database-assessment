Param(
[string]$user = "userfordma",
[string]$pass = "P@ssword135"
)


$objs = Import-Csv -Delimiter "," sqlsrv.csv
$foldername = ""
foreach($item in $objs) {
    $sqlsrv = $item.InstanceName
    $obj = sqlcmd -S $sqlsrv -i foldername.sql -U $user -P $pwd | findstr /v /c:"---"
    $splitobj = $obj[1].Split('')
    $values = $splitobj | ForEach-Object { if($_.Trim() -ne '') { $_ } }

    $dbversion = $values[0].Replace('.','')
    $machinename = $values[1]
    $dbname = $values[2]
    $instancename = $values[3]
    $current_ts = $values[4]

    $op_version = '4.2.1'

    $foldername = 'opdb' + '_' + 'sqlsrv' + '_' + 'PerfCounter' + '__' + $dbversion + '_' + $op_version + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts

    New-Item -Name $foldername -ItemType Directory

    $compFileName = 'opdb' + '__' + 'ComponentsInstalled' + '__' + $dbversion + '_' + $op_version + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
    $srvFileName = 'opdb' + '__' + 'ServerProperties' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
    $blockingFeatures = 'opdb' + '__' + 'BlockingFeatures' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
    $linkedServers = 'opdb' + '__' + 'LinkedServers' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'
    $perfMonData = 'opdb' + '__' + 'PerfMonData' + '__' + $dbversion + '_' + $op_version  + '_' + $machinename + '_' + $dbname + '_' + $instancename + '_' + $current_ts + '.csv'

    sqlcmd -S $sqlsrv -i sql\ComponentsInstalled.sql -U $user -P $pass -s"|" | findstr /v /c:"---" > $foldername\$compFileName
    sqlcmd -S $sqlsrv -i sql\ServerProperties.sql -U $user -P $pass -s"|" | findstr /v /c:"---" > $foldername\$srvFileName
    sqlcmd -S $sqlsrv -i sql\Features.sql -U $user -P $pass -m 1 -s"|" | findstr /v /c:"---" > $foldername\$blockingFeatures
    sqlcmd -S $sqlsrv -i sql\LinkedServers.sql -U $user -P $pass -m 1 -s"|" | findstr /v /c:"---" > $foldername\$linkedServers

    .\dma_sqlserver_perfmon_dataset.ps1 -operation collect -perfmonFilename $perfMonData

    $zippedopfolder = $foldername + '.zip'
    Compress-Archive -Path $foldername -DestinationPath $zippedopfolder
    Remove-Item -Path $foldername -Recurse -Force
}
