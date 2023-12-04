select chr(34) || :PKEY || chr(34) as pkey,
    chr(34) || :DMA_SOURCE_ID || chr(34) as dma_source_id,
    chr(34) || :DMA_MANUAL_ID || chr(34) as dma_manual_id,
    chr(34) || application_name || chr(34) as application_name,
    chr(34) || count(*) || chr(34) as application_count
from pg_stat_activity
group by 1,
    2,
    3,
    4
