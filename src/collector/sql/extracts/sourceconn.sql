spool &outputdir/opdb__sourceconn__&v_tag

WITH vsrcconn AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       has.dbid,
       has.instance_number,
       TO_CHAR(dhsnap.begin_interval_time, 'hh24') hour,
       replace(has.program, '|', '_') program,
       replace(has.module, '|', '_') module,
       replace(has.machine, '|', '_') machine,
       scmd.command_name,
       count(1) cnt
FROM &v_tblprefix._HIST_ACTIVE_SESS_HISTORY has
     INNER JOIN &v_tblprefix._HIST_SNAPSHOT dhsnap
     ON has.snap_id = dhsnap.snap_id
     AND has.instance_number = dhsnap.instance_number
     AND has.dbid = dhsnap.dbid
        INNER JOIN V$SQLCOMMAND scmd
        ON has.sql_opcode = scmd.COMMAND_TYPE
WHERE  has.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
AND has.dbid = &&v_dbid
AND has.session_type = 'FOREGROUND'
group by '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora',
       TO_CHAR(dhsnap.begin_interval_time, 'hh24'),
       has.dbid,
       has.instance_number,
       has.program,
       has.module,
       has.machine,
       scmd.command_name)
SELECT pkey , dbid , instance_number , hour , program ,
       module , machine , command_name , cnt
FROM vsrcconn
order by hour;
spool off
