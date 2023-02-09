$objs = Import-Csv -Delimiter "," sqlsrv.csv
foreach($item in $objs) {
$sqlsrv = $item.InstanceName +", " + $item.Port 
sqlcmd -H $sqlsrv -i SizingCPU.sql -o output\SizingCPU.csv -s"|"
sqlcmd -H $sqlsrv -i TableTypes.sql -o output\TableTypes.csv -s"|"
sqlcmd -H $sqlsrv -i Indexes.sql -o output\Indexes.csv -s"|"
sqlcmd -H $sqlsrv -i Views.sql -o output\ViewCnt.csv -s"|"
sqlcmd -H $sqlsrv -i Constraints.sql -o output\ConstraintCnt.csv -s"|"
sqlcmd -H $sqlsrv -i CollationPerDB.sql -o output\CollationPerDB.csv -s"|"
sqlcmd -H $sqlsrv -i CollationPerColumn.sql -o output\CollationPerColumn.csv -s"|"
sqlcmd -H $sqlsrv -i Synonyms.sql -o output\Synonyms.csv -s"|"
sqlcmd -H $sqlsrv -i LinkedServers.sql -o output\LinkedServers.csv -s"|"
sqlcmd -H $sqlsrv -i security.sql -o output\security.csv -s"|"
}