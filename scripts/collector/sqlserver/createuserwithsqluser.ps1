# Parameter help description
Param(
[Parameter(Mandatory=$true)][string]$user,
[Parameter(Mandatory=$true)][string]$pass
)
$objs = Import-Csv -Delimiter "," sqlsrv.csv
foreach($item in $objs) {
    $sqlsrv = $item.InstanceName
    sqlcmd -H $sqlsrv -i sql\prereq_createsa.sql -U $user -P $pass -m 1
}
