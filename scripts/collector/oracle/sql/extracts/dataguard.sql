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
COLUMN DEST_ID FORMAT 9999999999
COLUMN DEST_NAME FORMAT A20
COLUMN DESTINATION FORMAT A200
COLUMN STATUS FORMAT A20
COLUMN TARGET FORMAT A20
COLUMN SCHEDULE FORMAT A20
COLUMN REGISTER FORMAT A20
COLUMN ALTERNATE FORMAT A20
COLUMN TRANSMIT_MODE FORMAT A20
COLUMN AFFIRM FORMAT A20
COLUMN VALID_ROLE FORMAT A20
COLUMN VERIFY FORMAT A20
COLUMN LOG_ARCHIVE_CONFIG FORMAT A200

spool &outputdir/opdb__dataguard__&v_tag
prompt PKEY|CON_ID|INST_ID|LOG_ARCHIVE_CONFIG|DEST_ID|DEST_NAME|DESTINATION|STATUS|TARGET|SCHEDULE|REGISTER|ALTERNATE|TRANSMIT_MODE|AFFIRM|VALID_ROLE|VERIFY|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vodg AS (
SELECT  :v_pkey AS pkey,
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
        &v_dg_valid_role AS valid_role,
        &v_dg_verify     AS verify,
        'N/A' as log_archive_config
FROM gv$archive_dest a
WHERE destination IS NOT NULL)
SELECT pkey , con_id , inst_id , log_archive_config , dest_id , dest_name , destination , status ,
       target , schedule , register , alternate ,
       transmit_mode , affirm , valid_role , verify,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vodg;
spool off

COLUMN DEST_ID CLEAR
COLUMN DEST_NAME CLEAR
COLUMN DESTINATION CLEAR
COLUMN STATUS CLEAR
COLUMN TARGET CLEAR
COLUMN SCHEDULE CLEAR
COLUMN REGISTER CLEAR
COLUMN ALTERNATE CLEAR
COLUMN TRANSMIT_MODE CLEAR
COLUMN AFFIRM CLEAR
COLUMN VALID_ROLE CLEAR
COLUMN VERIFY CLEAR
COLUMN LOG_ARCHIVE_CONFIG CLEAR
