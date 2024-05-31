/*
 Copyright 2024 Google LLC

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 https://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */
select concat(char(34), @PKEY, char(34)) as pkey,
  concat(char(34), @DMA_SOURCE_ID, char(34)) as dma_source_id,
  concat(char(34), @DMA_MANUAL_ID, char(34)) as dma_manual_id,
  concat(char(34), src.table_catalog, char(34)) as table_catalog,
  concat(char(34), src.table_schema, char(34)) as table_schema,
  concat(char(34), src.table_name, char(34)) as table_name,
  concat(char(34), src.data_type, char(34)) as data_type,
  src.data_type_count as data_type_count
from (
    select i.table_catalog as table_catalog,
      i.TABLE_SCHEMA as table_schema,
      i.TABLE_NAME as table_name,
      i.DATA_TYPE as data_type,
      count(1) as data_type_count
    from information_schema.columns i
    where i.TABLE_SCHEMA not in (
        'mysql',
        'information_schema',
        'performance_schema',
        'sys'
      )
    group by i.table_catalog,
      i.TABLE_SCHEMA,
      i.TABLE_NAME,
      i.DATA_TYPE
  ) src;
