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
with all_schemas as (
  select n.oid as object_id,
    n.nspname as object_schema,
    pg_get_userbyid(n.nspowner) as schema_owner,
    case
      when n.nspname !~ '^pg_'
      and (
        n.nspname <> all (ARRAY ['pg_catalog' , 'information_schema'])
      ) then false
      else true
    end as system_object
  from pg_namespace n
),
all_tables as (
  select c.relnamespace as object_id,
    count(*) as table_count
  from pg_class c
  where c.relkind = ANY (ARRAY ['r', 'p'])
  group by c.relnamespace
),
all_functions as (
  select p.pronamespace as object_id,
    count(*) as function_count
  from pg_proc p
  group by p.pronamespace
),
all_views as (
  select c.relnamespace as object_id,
    count(*) as view_count
  from pg_class c
  where c.relkind = ANY (ARRAY ['v' , 'm' ])
  group by c.relnamespace
)
select chr(34) || :PKEY || chr(34) as pkey,
  chr(34) || :DMA_SOURCE_ID || chr(34) as dma_source_id,
  chr(34) || :DMA_MANUAL_ID || chr(34) as dma_manual_id,
  s.object_schema,
  s.schema_owner,
  s.system_object,
  COALESCE(t.table_count, 0) as table_count,
  COALESCE(v.view_count, 0) as view_count,
  COALESCE(f.function_count, 0) as function_count,
  0 as table_data_size_bytes,
  0 as total_table_size_bytes,
  chr(34) || current_database() || chr(34) as database_name
from all_schemas s
  left join all_tables t on s.object_id = t.object_id
  left join all_views v on s.object_id = v.object_id
  left join all_functions f on s.object_id = f.object_id;
