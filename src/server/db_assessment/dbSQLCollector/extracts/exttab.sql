spool &outputdir/opdb__exttab__&v_tag

WITH vexttab AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       &v_a_con_id as con_id, owner, table_name, type_owner, type_name, default_directory_owner, default_directory_name
FROM &v_tblprefix._external_tables a)
SELECT pkey , con_id , owner , table_name , type_owner , type_name ,
       default_directory_owner , default_directory_name
FROM vexttab;
spool off
