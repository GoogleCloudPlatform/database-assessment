with src as (
    select e.oid as extension_id,
        e.extname as extension_name,
        a.rolname as extension_owner,
        n.nspname as extension_schema,
        e.extrelocatable as is_relocatable,
        e.extversion as extension_version
    from pg_extension e
        join pg_authid a on (e.extowner = a.oid)
        join pg_namespace n on (e.extnamespace = n.oid)
)
select chr(39) || :DMA_SOURCE_ID || chr(39) as pkey,
    chr(39) || :DMA_SOURCE_ID || chr(39) as dma_source_id,
    chr(39) || :DMA_MANUAL_ID || chr(39) as dma_manual_id,
    src.extension_id,
    src.extension_name,
    src.extension_owner,
    src.extension_schema,
    src.is_relocatable,
    src.extension_version
from src;
