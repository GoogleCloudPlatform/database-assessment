-- name: collector-mysql-5-resource-groups
select concat(char(34), @PKEY, char(34)) as pkey,
  concat(char(34), @DMA_SOURCE_ID, char(34)) as dma_source_id,
  concat(char(34), @DMA_MANUAL_ID, char(34)) as dma_manual_id,
  concat(char(34), src.resource_group_name, char(34)) as resource_group_name,
  concat(char(34), src.resource_group_type, char(34)) as resource_group_type,
  concat(char(34), src.resource_group_enabled, char(34)) as resource_group_enabled,
  concat(char(34), src.vcpu_ids, char(34)) as vcpu_ids,
  concat(char(34), src.thread_priority, char(34)) as thread_priority
from (
    select 'Unsupported Version Placeholder' as resource_group_type,
      0 as resource_group_enabled,
      'Placeholder Value' as resource_group_name,
      '' as vcpu_ids,
      0 as thread_priority
    limit 0
  ) src;
