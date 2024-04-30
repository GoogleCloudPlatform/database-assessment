-- name: collection-postgres-applications
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    application_name as application_name,
    count(*) as application_count
from pg_stat_activity
group by 1,
    2,
    3,
    4
