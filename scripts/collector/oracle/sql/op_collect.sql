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

set termout on pause on
SET DEFINE "&"
DEFINE dmaVersion=&1
DEFINE SQLDIR=&2
DEFINE s_useawr=&3
DEFINE s_tag=&4
DEFINE outputdir=&5
DEFINE s_manualUniqueId=&6
DEFINE p_statsWindow=&7

DEFINE EXTRACTSDIR=&SQLDIR/extracts
DEFINE AWRDIR=sql/extracts/awr
DEFINE STATSPACKDIR=sql/extracts/statspack
DEFINE TERMOUTOFF=OFF
prompt
prompt ***********************************************************************************
prompt
prompt !!! ATTENTION !!!
prompt
@&SQLDIR/prompt_&s_useawr.
prompt
prompt
prompt ***********************************************************************************
prompt

prompt Initializing Database Migration Assessment Collector...
prompt
set termout &TERMOUTOFF
@@op_collect_init.sql
set termout on
prompt
prompt Initialization completed.


prompt
prompt Collecting Database Migration Assessment data...
prompt

set termout &TERMOUTOFF
@sql/extracts/defines.sql
@sql/extracts/archlogs.sql
@sql/extracts/users.sql
@sql/extracts/&s_ora9ind.backups.sql
@sql/extracts/columntypes.sql
-- @sql/extracts/compressbytype.sql
@sql/extracts/&s_ora9ind.cpucoresusage.sql
@sql/extracts/dataguard.sql
@sql/extracts/datatypes.sql
@sql/extracts/&s_ora9ind.dbfeatures.sql
@sql/extracts/&s_ora9ind.dbhwmarkstatistics.sql
@sql/extracts/dbinstances.sql
@sql/extracts/dblinks.sql
@sql/extracts/dbobjects.sql
@sql/extracts/dbobjectnames.sql
@sql/extracts/dbparameters.sql
@sql/extracts/dbsummary.sql
@sql/extracts/exttab.sql
@sql/extracts/idxpertable.sql
@sql/extracts/indextypes.sql
@sql/extracts/indextypedtl.sql
@sql/extracts/mviewtypes.sql
@sql/extracts/opkeylog.sql
@sql/extracts/sourcecode.sql
@sql/extracts/dtlsourcecode.sql
@sql/extracts/tablesnopk.sql
@sql/extracts/tableconstraints.sql
@sql/extracts/tabletypes.sql
@sql/extracts/tabletypedtl.sql
@sql/extracts/triggers.sql
@sql/extracts/usedspacedetails.sql
@sql/extracts/usrsegatt.sql
@sql/&s_dopluggable.
@sql/op_collect_&s_useawr.
@sql/extracts/lobsizing.sql
@sql/extracts/eoj.sql

set termout on
prompt Step completed.
prompt
prompt Database Migration Assessment data successfully extracted.
prompt
exit
