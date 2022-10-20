/*
Copyright 2022 Google LLC

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
spool &outputdir/opdb__cpucoresusage__&v_tag

WITH vcpursc AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                          AS pkey,
       TO_CHAR(timestamp, 'MM/DD/YY HH24:MI') dt,
       cpu_count,
       cpu_core_count,
       cpu_socket_count
FROM   dba_cpu_usage_statistics
ORDER  BY timestamp)
SELECT pkey , dt , cpu_count , cpu_core_count , cpu_socket_count
FROM vcpursc;
spool off
