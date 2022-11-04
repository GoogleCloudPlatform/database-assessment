spool &outputdir/opdb__dbfeatures__&v_tag

WITH vdbf AS(
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                                 AS pkey,
       &v_a_con_id AS con_id,
       REPLACE(name, ',', '/')                       name,
       currently_used,
       detected_usages,
       total_samples,
       TO_CHAR(first_usage_date, 'MM/DD/YY HH24:MI') first_usage,
       TO_CHAR(last_usage_date, 'MM/DD/YY HH24:MI')  last_usage,
       aux_count
FROM   &v_tblprefix._feature_usage_statistics a
ORDER  BY name)
SELECT pkey , con_id , name , currently_used , detected_usages ,
       total_samples , first_usage , last_usage , aux_count
FROM vdbf;
spool off
