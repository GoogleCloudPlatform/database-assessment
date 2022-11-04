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
spool &outputdir/opdb__dataguard__&v_tag

WITH vodg AS (
SELECT  '&&v_host'
        || '_'
        || '&&v_dbname'
        || '_'
        || '&&v_hora' AS pkey,
        &v_a_con_id as con_id, inst_id, 
        dest_id, 
        dest_name, 
        REPLACE(destination ,'|', ' ')destination, 
        status, 
        REPLACE(target  ,'|', ' ')target, 
        schedule, 
        register,
        REPLACE(alternate  ,'|', ' ')alternate, 
        transmit_mode, 
        affirm, 
        REPLACE(valid_role ,'|', ' ') valid_role, 
        verify,
        REPLACE(SUBSTR(CASE WHEN target = 'STANDBY' OR target = 'REMOTE' THEN (SELECT DECODE(listagg(value, ';') WITHIN GROUP (ORDER BY value), NULL, 'LOG_ARCHIVE_CONFIG_NOT_CONFIGURED', listagg(value, ';') WITHIN GROUP (ORDER BY value)) FROM gv$parameter WHERE UPPER(name) = 'LOG_ARCHIVE_CONFIG') ELSE 'LOCAL_DESTINATION_CONFIG_NOT_APPLICABLE' END, 1, 100), '|', ' ') log_archive_config
FROM gv$archive_dest a
WHERE destination IS NOT NULL)
SELECT pkey , con_id , inst_id , log_archive_config , dest_id , dest_name , destination , status ,
       target , schedule , register , alternate ,
       transmit_mode , affirm , valid_role , verify
FROM vodg;
spool off
