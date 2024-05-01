-- name: collection-mysql-plugins
select @PKEY as pkey,
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id,
    src.plugin_name as plugin_name,
    src.plugin_version as plugin_version,
    src.plugin_status as plugin_status,
    src.plugin_type as plugin_type,
    src.plugin_type_version as plugin_type_version,
    src.plugin_library as plugin_library,
    src.plugin_library_version as plugin_library_version,
    src.plugin_author as plugin_author,
    src.plugin_description as plugin_description,
    src.plugin_license as plugin_license,
    src.load_option as load_option
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
