SELECT TRIM(a.pkey)            ckey,
       TRIM(a.inst_id)         inst_id,
       TRIM(a.instance_name)   instance_name,
       TRIM(a.host_name)       hostname,
       TRIM(a.version)         version,
       TRIM(a.status)          status,
       TRIM(a.database_status) database_status,
       TRIM(a.instance_role)   instance_role
FROM   ${dataset}.dbinstances a; 
