$objs = Import-Csv -Delimiter "," sqlsrv.csv
foreach($item in $objs) {
    $sqlsrv = $item.InstanceName
    sqlcmd -S $sqlsrv -i sql\prereq_createsa.sql -m 1
}
