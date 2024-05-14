-- name: extended-collection-postgres-all-databases
with src as (
  select datname
  from pg_catalog.pg_database
  where datname not in (
      'template0',
      'template1',
      'rdsadmin',
      'cloudsqladmin',
      'alloydbadmin',
      'alloydbmetadata',
      'azure_maintenance',
      'azure_sys'
    )
    and not datistemplate
)
select :PKEY as pkey,
  :DMA_SOURCE_ID as dma_source_id,
  :DMA_MANUAL_ID as dma_manual_id,
  src.datname as database_name
from src;
