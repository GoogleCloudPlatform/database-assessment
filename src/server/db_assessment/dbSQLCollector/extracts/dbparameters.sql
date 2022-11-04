spool &outputdir/opdb__dbparameters__&v_tag

WITH vparam AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                                   AS pkey,
       inst_id,
       &v_a_con_id AS con_id,
       REPLACE(name, ',', '/')                         name,
       TRANSLATE(REPLACE(SUBSTR(value, 1, 60), ',', '/'), chr(10)||chr(13) , '  ')         value,
       TRANSLATE(REPLACE(SUBSTR(&v_dbparam_dflt_col, 1, 30), ',', '/'), chr(10)||chr(13), '  ') default_value,
       isdefault
FROM   gv$parameter a
ORDER  BY 2,3 )
SELECT pkey , inst_id , con_id , name , value , default_value , isdefault
FROM vparam;
spool off
