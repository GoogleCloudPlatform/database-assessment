--name: transform-09
create or replace view V_DS_BMS_BOM as With bms_servers as (
        select bms_server_size,
            count(BMS_Server_size) as Count
        from T_DS_BMS_sizing as BMSsizing
        group by BMS_Server_size
    ),
    BOM as (
        select CASE
                when bms_server_size = 'XS' then '8 CORE 192 GB DRAM'
                when bms_server_size = 'S' then '16 CORE 384 GB DRAM'
                when bms_server_size = 'M' then '24 CORE 768 GB DRAM'
                when bms_server_size = 'L' then '56 CORE 1536 GB DRAM'
                when bms_server_size = 'XL' then '112 CORE 3072 GB DRAM'
            end as BMS_SKU,
            bms_servers.count
        from bms_servers
    ),
    SSD_storage as (
        select sum(SSD_Storage_TB) as SSD_Storage_TB
        from T_DS_BMS_sizing as BMSsizing
        where Perferred_storage = 'SSD'
    ),
    HT_storage as (
        select sum(High_Throughput_per_4TB) as High_Throughput_per_4TB
        from T_DS_BMS_sizing as BMSsizing
        where Perferred_storage = 'HT'
    ),
    HT_storage_add as (
        select CASE
                when DB_size_TB > (CEIL(High_Throughput_per_4TB * 4)) then CEIL(DB_size_TB - (High_Throughput_per_4TB * 4))
                else 0
            end as High_Throughput_additional
        from T_DS_BMS_sizing as BMSsizing
        where Perferred_storage = 'HT'
    ),
    FinalTable as (
        select *
        from BOM
        union all
        select 'All SSD Storage / TB',
            SSD_Storage_TB
        from SSD_storage
        union all
        select 'HT SSD Storage (Initial 4TB)',
            High_Throughput_per_4TB
        from HT_storage
        union all
        select 'HT SSD Storage (Additional 1TB)',
            sum(High_Throughput_additional)
        from HT_storage_add
        order by 1
    )
select *
from FinalTable;