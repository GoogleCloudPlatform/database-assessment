\ o output / opdb__settings_ :VTAG.csv;

with src as (
    select s.category as setting_category,
        s.name as setting_name,
        s.setting as setting_value,
        s.unit as setting_unit,
        s.context as context,
        s.vartype as variable_type,
        s.source as setting_source,
        s.min_val as min_value,
        s.max_val as max_value,
        s.enumvals as enum_values,
        s.boot_val as boot_value,
        s.reset_val as reset_value,
        s.sourcefile as source_file,
        s.pending_restart as pending_restart
    from pg_settings s
)
select chr(39) || :PKEY || chr(39) as pkey,
    chr(39) || :DMA_SOURCE_ID || chr(39) as dma_source_id,
    chr(39) || :DMA_MANUAL_ID || chr(39) as dma_manual_id,
    src.setting_category,
    src.setting_name,
    src.setting_value,
    src.setting_unit,
    src.context,
    src.variable_type,
    src.setting_source,
    src.min_value,
    src.max_value,
    src.enum_values,
    src.boot_value,
    src.reset_value,
    src.source_file,
    src.pending_restart
from src;
