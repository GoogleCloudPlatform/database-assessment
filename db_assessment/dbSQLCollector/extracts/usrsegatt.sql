spool &outputdir/opdb__usrsegatt__&v_tag

WITH vuseg AS (
 SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                          AS pkey,
        &v_a_con_id AS con_id,
        owner,
        segment_name,
        segment_type,
        tablespace_name
 FROM &v_tblprefix._segments a
 WHERE tablespace_name IN ('SYSAUX', 'SYSTEM')
 AND owner NOT IN
 (SELECT name
  FROM system.logstdby$skip_support
  WHERE action=0))
SELECT pkey , con_id , owner , segment_name , segment_type , tablespace_name
FROM vuseg;
spool off
