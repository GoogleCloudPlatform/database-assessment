column t_sqlstats   new_value  v_sqlstats noprint

SELECT  CASE WHEN '&v_dbversion' LIKE '10%' OR  '&v_dbversion' = '111' THEN '&AWRDIR/sqlstats111.sql' ELSE '&AWRDIR/sqlstats.sql' END as t_sqlstats
FROM DUAL;

@&AWRDIR/awrsnapdetails.sql
@&AWRDIR/awrhistcmdtypes.sql
@&AWRDIR/awrhistosstat.sql
@&AWRDIR/awrhistsysmetrichist.sql
@&AWRDIR/awrhistsysmetricsumm.sql
@&AWRDIR/dbahistsysstat.sql
@&AWRDIR/dbahistsystimemodel.sql
@&AWRDIR/ioevents.sql
--@&AWRDIR/iofunction.sql
@&AWRDIR/&v_io_function_sql
@&AWRDIR/sourceconn.sql
@&v_sqlstats
