select trim(a.pkey) ckey, b.db_name, b.cdb, b.dbversion, trim(a.inst_id) inst_id, trim(a.con_id) con_id, trim(a.name) name,
        trim(a.value) value, trim(a.default_value) default_value, trim(a.isdefault_value) isdefault_value
from `MYDATASET.dbparameters` a
inner join `MYDATASET.vdbsummary` b
on trim(a.pkey) = b.ckey;
