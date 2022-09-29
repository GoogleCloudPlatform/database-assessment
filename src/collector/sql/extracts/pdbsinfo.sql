spool &outputdir/opdb__pdbsinfo__&v_tag

WITH vpdbinfo AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       dbid,
       pdb_id,
       pdb_name,
       status,
       logging
FROM   &v_tblprefix._pdbs )
SELECT pkey , dbid , pdb_id , pdb_name , status , logging
FROM  vpdbinfo;
spool off
