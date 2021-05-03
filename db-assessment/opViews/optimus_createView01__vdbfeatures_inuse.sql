select trim(a.pkey) ckey, trim(a.con_id) con_id, trim(a.name) name, trim(a.detected_usage) detected_usage, trim(a.first_usage) first_usage, trim(a.last_usage) last_usage
from `MYDATASET.dbfeatures` a
where trim(a.current_usage) = 'TRUE'
order by ckey, con_id, name;
