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
spool &outputdir/opdb__triggers__&v_tag
prompt PKEY|CON_ID|OWNER|TRIGGER_TYPE|TRIGGERING_EVENT|BASE_OBJECT_TYPE|TRIGGER_COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH trginfo AS (
SELECT
    &v_a_con_id AS con_id,
    owner,
    trigger_type,
    triggering_event,
    base_object_type,
    COUNT(1) AS trigger_count
FROM
    &v_tblprefix._triggers a
WHERE
    TRIM(base_object_type) IN ( 'DATABASE', 'SCHEMA' )
    AND status = 'ENABLED'
    AND ( owner, trigger_name ) NOT IN ( ( 'SYS', 'XDB_PI_TRIG' ),
                                         ( 'SYS', 'DELETE_ENTRIES' ),
                                         ( 'SYS', 'OJDS$ROLE_TRIGGER$' ),
                                         ( 'SYS', 'DBMS_SET_PDB' ),
                                         ( 'MDSYS', 'SDO_TOPO_DROP_FTBL' ),
                                         ( 'MDSYS', 'SDO_GEOR_BDDL_TRIGGER' ),
                                         ( 'MDSYS', 'SDO_GEOR_ADDL_TRIGGER' ),
                                         ( 'MDSYS', 'SDO_NETWORK_DROP_USER' ),
                                         ( 'MDSYS', 'SDO_ST_SYN_CREATE' ),
                                         ( 'MDSYS', 'SDO_DROP_USER' ),
                                         ( 'GSMADMIN_INTERNAL', 'GSMLOGOFF' ) ,
                                         ( 'SYSMAN', 'MGMT_STARTUP' ),
                                         ( 'SYS', 'AW_TRUNC_TRG' ),
                                         ( 'SYS', 'AW_REN_TRG' ) ,
                                         ( 'SYS', 'AW_DROP_TRG' )
                                         )
GROUP BY
    &v_a_con_id,
    owner,
    trigger_type,
    triggering_event,
    base_object_type)
SELECT :v_pkey AS pkey,
       con_id,
       owner,
       trigger_type,
       triggering_event,
       base_object_type,
       trigger_count,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM  trginfo;
spool off
