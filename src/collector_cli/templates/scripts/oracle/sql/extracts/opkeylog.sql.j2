--
-- Copyright 2024 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License").
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     https://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
COLUMN DB_NAME FORMAT A20
COLUMN INSTANCE_NAME FORMAT A20
spool &outputdir/opdb__opkeylog__&v_tag
prompt PKEY|OPSCRI|DB_|HOSTNAME|DB_NAME|INSTANCE_NAME|COLLECTION_T|DB_ID|C|DMA_SOURCE_ID|DMA_MANUAL_ID
with vop as (
select :v_pkey AS pkey,
'&&version' opscriptversion, '&&v_dbversion' db_version, '&&v_host' hostname,
'&&v_dbname' db_name, '&&v_inst' instance_name, '&&v_hora' collection_time, &&v_dbid db_id, null "CMNT"
from dual)
select pkey , opscriptversion , db_version , hostname
       , db_name , instance_name , collection_time , db_id , CMNT,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
from vop;
spool off
COLUMN DB_NAME CLEAR
COLUMN INSTANCE_NAME CLEAR
