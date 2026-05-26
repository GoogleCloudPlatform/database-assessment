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
WITH src AS (
  SELECT
    p.oid AS object_id,
    n.nspname AS schema_name,
    CASE
      WHEN p.prokind = 'f'
      THEN 'FUNCTION'
      WHEN p.prokind = 'p'
      THEN 'PROCEDURE'
      WHEN p.prokind = 'a'
      THEN 'AGGREGATE_FUNCTION'
      WHEN p.prokind = 'w'
      THEN 'WINDOW_FUNCTION'
      ELSE 'UNCATEGORIZED_PROCEDURE'
    END AS object_type,
    p.proname AS object_name,
    PG_GET_FUNCTION_RESULT(p.oid) AS result_data_types,
    PG_GET_FUNCTION_ARGUMENTS(p.oid) AS argument_data_types,
    PG_GET_USERBYID(p.proowner) AS object_owner,
    LENGTH(p.prosrc) AS number_of_chars,
    (
      LENGTH(p.prosrc) + 1
    ) - LENGTH(REPLACE(p.prosrc, e'\n', '')) AS number_of_lines,
    CASE WHEN p.prosecdef THEN 'definer' ELSE 'invoker' END AS object_security,
    ARRAY_TO_STRING(p.proacl, '') AS access_privileges,
    l.lanname AS procedure_language,
    CASE
      WHEN n.nspname <> ALL(ARRAY['pg_catalog', 'information_schema'])
      THEN FALSE
      ELSE TRUE
    END AS system_object
  FROM pg_proc AS p
  LEFT JOIN pg_namespace AS n
    ON n.oid = p.pronamespace
  LEFT JOIN pg_language AS l
    ON l.oid = p.prolang
)
SELECT
  :PKEY AS pkey,
  :DMA_SOURCE_ID AS dma_source_id,
  :DMA_MANUAL_ID AS dma_manual_id,
  src.object_id,
  src.schema_name AS schema_name,
  src.object_type,
  src.object_name AS object_name,
  src.result_data_types AS result_data_types,
  src.argument_data_types AS argument_data_types,
  src.object_owner AS object_owner,
  src.number_of_chars,
  src.number_of_lines,
  src.object_security,
  src.access_privileges,
  src.procedure_language,
  src.system_object
FROM src