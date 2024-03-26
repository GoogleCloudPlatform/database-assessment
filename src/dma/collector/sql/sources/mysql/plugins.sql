-- name: collection-mysql-plugins
select concat(char(34), @PKEY, char(34)) as pkey,
    concat(char(34), @DMA_SOURCE_ID, char(34)) as dma_source_id,
    concat(char(34), @DMA_MANUAL_ID, char(34)) as dma_manual_id,
    concat(char(34), src.plugin_name, char(34)) as plugin_name,
    concat(char(34), src.plugin_version, char(34)) as plugin_version,
    concat(char(34), src.plugin_status, char(34)) as plugin_status,
    concat(char(34), src.plugin_type, char(34)) as plugin_type,
    concat(char(34), src.plugin_type_version, char(34)) as plugin_type_version,
    concat(char(34), src.plugin_library, char(34)) as plugin_library,
    concat(char(34), src.plugin_library_version, char(34)) as plugin_library_version,
    concat(char(34), src.plugin_author, char(34)) as plugin_author,
    concat(char(34), src.plugin_description, char(34)) as plugin_description,
    concat(char(34), src.plugin_license, char(34)) as plugin_license,
    concat(char(34), src.load_option, char(34)) as load_option
from (
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
            load_option as load_option
        from information_schema.PLUGINS
    ) src;
