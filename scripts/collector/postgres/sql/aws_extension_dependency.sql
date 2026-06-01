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
with dependencies as (
  /* Functions dependent on AWS extensions */
  select n.nspname as schema_name,
    p.proname as object_name,
    'SOURCE_CODE' as object_type,
    l.lanname as object_language,
    ext.extname as aws_extension_dependency
  from pg_proc p
    join pg_namespace n on p.pronamespace = n.oid
    join pg_language l on p.prolang = l.oid
    join pg_depend d on p.oid = d.objid
    join pg_extension ext on d.refobjid = ext.oid
  where ext.extname in ('aws_commons', 'aws_s3', 'aws_lambda')
    and n.nspname <> all (array ['pg_catalog', 'information_schema'])
  union all
  /* Tables, Views, or Indexes dependent on AWS extensions */
  select n.nspname as schema_name,
    c.relname as object_name,
    case c.relkind
      when 'r' then 'TABLE'
      when 'v' then 'VIEW'
      when 'm' then 'MATERIALIZED_VIEW'
      when 'i' then 'INDEX'
      else 'OTHER_RELATION'
    end as object_type,
    'N/A' as object_language,
    ext.extname as aws_extension_dependency
  from pg_class c
    join pg_namespace n on c.relnamespace = n.oid
    join pg_depend d on c.oid = d.objid
    join pg_extension ext on d.refobjid = ext.oid
  where ext.extname in ('aws_commons', 'aws_s3', 'aws_lambda')
    and n.nspname <> all (array ['pg_catalog', 'information_schema'])
)
select chr(34) || :PKEY || chr(34) as pkey,
  chr(34) || :DMA_SOURCE_ID || chr(34) as dma_source_id,
  chr(34) || :DMA_MANUAL_ID || chr(34) as dma_manual_id,
  chr(34) || schema_name || chr(34) as schema_name,
  chr(34) || object_language || chr(34) as object_language,
  chr(34) || object_type || chr(34) as object_type,
  chr(34) || object_name || chr(34) as object_name,
  chr(34) || aws_extension_dependency || chr(34) as aws_extension_dependency,
  count(*) as sct_function_reference_count
from dependencies d
group by 1, 2, 3, 4, 5, 6, 7, 8;
