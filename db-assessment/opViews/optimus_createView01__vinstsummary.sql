select trim(a.pkey) ckey, 
        trim(a.inst_id) inst_id,
        trim(a.instance_name) instance_name,
        trim(a.host_name) hostname,
        trim(a.version) version,
        trim(a.status) status,
        trim(a.database_status) database_status,
        trim(a.instance_role) instance_role
from `MYDATASET.dbinstances` a;
