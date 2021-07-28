SELECT TRIM(a.pkey)            ckey,
       b.db_name,
       b.cdb,
       b.dbversion,
       TRIM(a.inst_id)         inst_id,
       TRIM(a.con_id)          con_id,
       TRIM(a.name)            name,
       TRIM(a.value)           value,
       TRIM(a.default_value)   default_value,
       TRIM(a.isdefault_value) isdefault_value
FROM   ${dataset}.dbparameters a
       INNER JOIN ${dataset}.vdbsummary b
               ON TRIM(a.pkey) = b.ckey; 
