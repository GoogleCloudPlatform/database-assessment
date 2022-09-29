spool &outputdir/opdb__tablesnopk__&v_tag

WITH vnopk AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'              AS pkey,
       con_id,
       owner,
       SUM(pk)                    pk,
       SUM(uk)                    uk,
       SUM(ck)                    ck,
       SUM(ri)                    ri,
       SUM(vwck)                  vwck,
       SUM(vwro)                  vwro,
       SUM(hashexpr)              hashexpr,
       SUM(suplog)                suplog,
       COUNT(DISTINCT table_name) num_tables,
       COUNT(1)                   total_cons
FROM   (SELECT &v_a_con_id AS con_id,
               a.owner,
               a.table_name,
               DECODE(b.constraint_type, 'P', 1,
                                         NULL) pk,
               DECODE(b.constraint_type, 'U', 1,
                                         NULL) uk,
               DECODE(b.constraint_type, 'C', 1,
                                         NULL) ck,
               DECODE(b.constraint_type, 'R', 1,
                                         NULL) ri,
               DECODE(b.constraint_type, 'V', 1,
                                         NULL) vwck,
               DECODE(b.constraint_type, 'O', 1,
                                         NULL) vwro,
               DECODE(b.constraint_type, 'H', 1,
                                         NULL) hashexpr,
               DECODE(b.constraint_type, 'F', 1,
                                         NULL) refcolcons,
               DECODE(b.constraint_type, 'S', 1,
                                         NULL) suplog
        FROM   &v_tblprefix._tables a
               left outer join &v_tblprefix._constraints b
                            ON &v_a_con_id = &v_b_con_id
                               AND a.owner = b.owner
                               AND a.table_name = b.table_name)
GROUP  BY '&&v_host'
          || '_'
          || '&&v_dbname'
          || '_'
          || '&&v_hora',
          con_id,
          owner)
SELECT pkey , con_id , owner , pk , uk , ck ,
       ri , vwck , vwro , hashexpr , suplog , num_tables , total_cons
FROM vnopk;
spool off
