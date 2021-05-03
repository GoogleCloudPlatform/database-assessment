select  a.hostname, 
        a.memory_max_target_gb, a.memory_target_gb, a.sga_max_size_gb, a.sga_target_gb, a.pga_aggregate_target_gb,
        case memory_max_target_gb
            when 0.0 then sga_max_size_gb+pga_aggregate_target_gb
            else memory_max_target_gb
        end db_total_memory_gb
from (
select b.hostname,  
        round(sum(a.memory_max_target)/1024/1024/1024,1) memory_max_target_gb, round(sum(a.memory_target)/1024/1024/1024,1) memory_target_gb,
        round(sum(a.sga_max_size)/1024/1024/1024,1) sga_max_size_gb, round(sum(a.sga_target)/1024/1024/1024,1) sga_target_gb,
        round(sum(a.pga_aggregate_target)/1024/1024/1024,1) pga_aggregate_target_gb
from (
select trim(a.pkey) ckey, trim(a.inst_id) inst_id, trim(a.con_id) con_id,
        case trim(name)
                when 'memory_max_target' then cast(trim(a.value) as int64)
            end as memory_max_target,
        case trim(name)
                when 'memory_target' then cast(trim(a.value) as int64)
            end as memory_target,
        case trim(name)
                when 'sga_max_size' then cast(trim(a.value) as int64)
            end as sga_max_size,
        case trim(name)
                when 'sga_target' then cast(trim(a.value) as int64)
            end as sga_target,
        case trim(name)
                when 'pga_aggregate_target' then cast(trim(a.value) as int64)
            end as pga_aggregate_target
from `MYDATASET.dbparameters` a
where trim(name) in ('memory_max_target','memory_target','sga_max_size','sga_target','pga_aggregate_target')
) a
inner join `MYDATASET.vinstsummary` b
on a.ckey = b.ckey and a.inst_id = b.inst_id
group by b.hostname
) a;
