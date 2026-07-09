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
select distinct concat(char(34), @PKEY, char(34)) as pkey,
  concat(char(34), @DMA_SOURCE_ID, char(34)) as dma_source_id,
  concat(char(34), @DMA_MANUAL_ID, char(34)) as dma_manual_id,
  concat(char(34), src.variable_category, char(34)) as variable_category,
  concat(char(34), src.variable_name, char(34)) as variable_name,
  concat(char(34), src.variable_value, char(34)) as variable_value
from (
    select 'CALCULATED_METRIC' as variable_category,
      variable_name,
      variable_value
    from (
        select 'DATAFILE_SIZE_BYTES' as variable_name,
          allocated_size as variable_value
        from (
		select
			sum(allocated_size) as allocated_size
		from
			(
			with systs as (
				select
					tablespace_name,
					total_extents + 1 as total_extents,
					extent_size
				from
					information_schema.FILES f
				where
					tablespace_name = 'innodb_system'
                                )
				select
					tablespace_name,
					total_extents * extent_size as allocated_size
				from
					systs
			union
				select
					name as tablespace_name,
					allocated_size
				from
					information_schema.INNODB_TABLESPACES it 
		) file_sizes
          ) as variable_value
      ) calculated_metrics
    UNION
    select 'ALL_VARIABLES' as variable_category,
      variable_name,
      variable_value
    from (
        select variable_name,
          variable_value
        from (
            select upper(variable_name) as variable_name,
              variable_value
            from performance_schema.global_variables
            union
            select upper(variable_name),
              variable_value
            from performance_schema.session_variables
            where variable_name not in (
                select variable_name
                from performance_schema.global_variables
              )
          ) a
        where a.variable_name not in ('FT_BOOLEAN_SYNTAX')
          and a.variable_name not like '%PUBLIC_KEY'
          and a.variable_name not like '%PRIVATE_KEY'
      ) all_vars
    union
    select 'GLOBAL_STATUS' as variable_category,
      variable_name,
      variable_value
    from (
        select upper(variable_name) as variable_name,
          variable_value
        from performance_schema.global_status a
        where a.variable_name not in ('FT_BOOLEAN_SYNTAX')
          and a.variable_name not like '%PUBLIC_KEY'
          and a.variable_name not like '%PRIVATE_KEY'
      ) global_status
    union
    select 'CALCULATED_METRIC' as variable_category,
      variable_name,
      variable_value
    from (
        select 'IS_MARIADB' as variable_name,
          if(upper(gv.variable_value) like '%MARIADB%', 1, 0) as variable_value
        from performance_schema.global_variables gv
        where gv.variable_name = 'VERSION'
        union
        select 'TABLE_SIZE' as variable_name,
          total_data_size_bytes as variable_value
        from (
            select sum(data_length) as total_data_size_bytes
            from (
                select t.table_schema as table_schema,
                  t.table_name as table_name,
                  t.table_rows as table_rows,
                  t.DATA_LENGTH as DATA_LENGTH,
                  t.INDEX_LENGTH as INDEX_LENGTH,
                  t.DATA_LENGTH + t.INDEX_LENGTH as total_length,
                  t.ROW_FORMAT as row_format,
                  t.TABLE_TYPE as table_type,
                  t.ENGINE as table_engine,
                  if(pks.table_name is not null, 1, 0) as has_primary_key
                from information_schema.TABLES t
                  left join (
                    select table_schema,
                      TABLE_NAME
                    from information_schema.statistics
                    where table_schema not in (
                        'mysql',
                        'information_schema',
                        'performance_schema',
                        'sys'
                      )
                    group by table_schema,
                      TABLE_NAME,
                      index_name
                    having SUM(
                        if(
                          non_unique = 0
                          and NULLABLE != 'YES',
                          1,
                          0
                        )
                      ) = count(*)
                  ) pks on (
                    t.table_schema = pks.table_schema
                    and t.TABLE_NAME = pks.TABLE_NAME
                  )
                where t.table_schema not in (
                    'mysql',
                    'information_schema',
                    'performance_schema',
                    'sys'
                  )
              ) user_tables
         ) data_summary
      ) metrics
  ) src;
