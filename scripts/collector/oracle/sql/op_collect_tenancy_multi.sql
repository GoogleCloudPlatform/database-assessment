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
spool &outputdir./opdb__pdbsinfo__&s_tag.
prompt PKEY|DBID|PDB_ID|PDB_NAME|STATUS|LOGGING|CON_ID|CON_UID|EBS_OWNER|SIEBEL_OWNER|PSFT_OWNER|RDS_FLAG|OCI_AUTONOMOUS_FLAG|DBMS_CLOUD_PKG_INSTALLED|APEX_INSTALLED|SAP_OWNER|SGA_ALLOCATED_BYTES|PGA_USED_BYTES|PGA_ALLOCATED_BYTES|PGA_MAX_BYTES|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/pdbsinfo.sql
spool off


spool &outputdir./opdb__pdbsopenmode__&s_tag.
prompt PKEY|CON_ID|NAME|OPEN_MODE|TOTAL_GB|CON_UID|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/pdbsopenmode.sql
spool off


