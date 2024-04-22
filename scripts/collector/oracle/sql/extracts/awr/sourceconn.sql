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
COLUMN t_sql_cmd   NEW_VALUE  v_sql_cmd NOPRINT
COLUMN t_machine   NEW_VALUE  v_machine NOPRINT
COLUMN MACHINE FORMAT A60


SELECT  CASE WHEN '&v_dbversion' LIKE '10%' OR  '&v_dbversion' = '111' THEN '&AWRDIR/sqlcmd10.sql' ELSE '&AWRDIR/sqlcmd12.sql' END as t_sql_cmd,
        CASE WHEN '&v_dbversion' LIKE '10%' OR  '&v_dbversion' = '111' THEN '''N/A''' ELSE 'has.machine' END as t_machine
FROM DUAL;

spool &outputdir/opdb__sourceconn__&v_tag
prompt PKEY|DBID|INSTANCE_NUMBER|HO|PROGRAM|MODULE|MACHINE|COMMAND_NAME|CNT|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vsrcconn AS (
SELECT :v_pkey AS pkey,
       has.dbid,
       has.instance_number,
       TO_CHAR(dhsnap.begin_interval_time, 'hh24') hour,
       replace(has.program, '|', '_') program,
       replace(has.module, '|', '_') module,
       replace(&v_machine, '|', '_') machine,
       scmd.command_name,
       count(1) cnt
FROM &v_tblprefix._HIST_ACTIVE_SESS_HISTORY has
     INNER JOIN &v_tblprefix._HIST_SNAPSHOT dhsnap
     ON has.snap_id = dhsnap.snap_id
     AND has.instance_number = dhsnap.instance_number
     AND has.dbid = dhsnap.dbid
@&v_sql_cmd
        ON has.sql_opcode = scmd.COMMAND_TYPE
WHERE  has.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
AND has.dbid = &&v_dbid
AND has.session_type = 'FOREGROUND'
group by :v_pkey,
       TO_CHAR(dhsnap.begin_interval_time, 'hh24'),
       has.dbid,
       has.instance_number,
       has.program,
       has.module,
       &v_machine,
       scmd.command_name)
SELECT pkey , dbid , instance_number , hour , program ,
       module , machine , command_name , cnt,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vsrcconn
order by hour;
spool off
