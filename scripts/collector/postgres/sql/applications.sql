select chr(39) || :PKEY || chr(39) as pkey,
    chr(39) || :DMA_SOURCE_ID || chr(39) as dma_source_id,
    chr(39) || :DMA_MANUAL_ID || chr(39) as dma_manual_id,
    application_name as application_name,
    count(*) as application_count
from pg_stat_activity
group by 1
