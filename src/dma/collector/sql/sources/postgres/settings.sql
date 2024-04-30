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
        s.pending_restart as pending_restart,
        case
            when s.source not in ('override', 'default') then 1
            else 0
        end as is_default
    from pg_settings s
)
select chr(34) || :PKEY || chr(34) as pkey,
    chr(34) || :DMA_SOURCE_ID || chr(34) as dma_source_id,
    chr(34) || :DMA_MANUAL_ID || chr(34) as dma_manual_id,
    chr(34) || REPLACE(src.setting_category, chr(34), chr(39)) || chr(34) as setting_category,
    chr(34) || REPLACE(src.setting_name, chr(34), chr(39)) || chr(34) as setting_name,
    chr(34) || REPLACE(src.setting_value, chr(34), chr(39)) || chr(34) as setting_value,
    src.setting_unit,
    src.context,
    src.variable_type,
    src.setting_source,
    src.min_value,
    src.max_value,
    chr(34) || REPLACE(src.enum_values::text, chr(34), chr(39)) || chr(34) as enum_values,
    chr(34) || REPLACE(src.boot_value::text, chr(34), chr(39)) || chr(34) as boot_value,
    chr(34) || REPLACE(src.reset_value::text, chr(34), chr(39)) || chr(34) as reset_value,
    src.source_file,
    src.pending_restart,
    src.is_default
from src;
