SELECT TRIM(a.pkey)           ckey,
       TRIM(a.con_id)         con_id,
       TRIM(a.name)           name,
       TRIM(a.detected_usage) detected_usage,
       TRIM(a.first_usage)    first_usage,
       TRIM(a.last_usage)     last_usage
FROM   ${dataset}.dbfeatures a
WHERE  TRIM(a.current_usage) = 'TRUE'
ORDER  BY ckey,
          con_id,
          name; 
