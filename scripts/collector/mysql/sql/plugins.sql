with src as (
    select plugin_name as plugin_name,
        plugin_version as plugin_version,
        plugin_status as plugin_status,
        plugin_type as plugin_type,
        plugin_type_version as plugin_type_version,
        plugin_library as plugin_library,
        plugin_library_version as plugin_library_version,
        plugin_author as plugin_author,
        plugin_description as plugin_description,
        plugin_license as plugin_license,
        load_option as load_option,
        plugin_maturity as plugin_maturity,
        plugin_auth_version as plugin_auth_version
    from information_schema.PLUGINS
)
select concat(char(39), @DMA_MANUAL_ID, char(39)) as PKEY,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as DMA_SOURCE_ID,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_MANUAL_ID,
    src.plugin_name,
    src.plugin_version,
    src.plugin_status,
    src.plugin_type,
    src.plugin_type_version,
    src.plugin_library,
    src.plugin_library_version,
    src.plugin_author,
    src.plugin_description,
    src.plugin_license,
    src.load_option,
    src.plugin_maturity,
    src.plugin_auth_version
from src;
