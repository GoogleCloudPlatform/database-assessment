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
exec dbms_application_info.set_action('opkeylog');




with vop as (
select :v_pkey AS pkey,
:v_dmaVersion opscriptversion, :v_dbversion db_version, :v_host hostname,
:v_dbname db_name, :v_instance instance_name, :v_hora collection_time, :v_dbid db_id, null "CMNT"
from dual)
select pkey , opscriptversion , db_version , hostname
       , db_name , instance_name , collection_time , db_id , CMNT,
       :v_dma_source_id AS dma_source_id, :v_manual_unique_id AS dma_manual_id
from vop;



