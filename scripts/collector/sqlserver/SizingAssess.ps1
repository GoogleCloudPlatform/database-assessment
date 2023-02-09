$objs = Import-Csv -Delimiter "," sqlsrv.csv
foreach($item in $objs) {
$sqlsrv = $item.InstanceName +", " + $item.Port 
sqlcmd -H $sqlsrv -i SizingCPU.sql -o output\SizingCPU.csv -s"|"
sqlcmd -H $sqlsrv -i SizingMemory.sql -o output\SizingMemory.csv -s"|"
sqlcmd -H $sqlsrv -i SizingIOPS.sql -o output\SizingIOPS.csv -s"|"
}