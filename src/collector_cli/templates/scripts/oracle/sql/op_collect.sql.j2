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
DEFINE SQLDIR=&2
DEFINE v_dodiagnostics=&3
DEFINE v_tag=&4
DEFINE outputdir=&5
DEFINE v_manualUniqueId=&6
DEFINE v_statsWindow=&7

DEFINE EXTRACTSDIR=&SQLDIR/extracts
DEFINE AWRDIR=&EXTRACTSDIR/awr
DEFINE STATSPACKDIR=&EXTRACTSDIR/statspack
DEFINE TERMOUTOFF=OFF
prompt
prompt ***********************************************************************************
prompt
prompt !!! ATTENTION !!!
prompt
@&SQLDIR/prompt_&v_dodiagnostics
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
@&EXTRACTSDIR/defines.sql
@&EXTRACTSDIR/archlogs.sql
@&EXTRACTSDIR/users.sql
@&EXTRACTSDIR/&v_ora9ind.backups.sql
@&EXTRACTSDIR/columntypes.sql
-- @&EXTRACTSDIR/compressbytype.sql
@&EXTRACTSDIR/&v_ora9ind.cpucoresusage.sql
@&EXTRACTSDIR/dataguard.sql
@&EXTRACTSDIR/datatypes.sql
@&EXTRACTSDIR/&v_ora9ind.dbfeatures.sql
@&EXTRACTSDIR/&v_ora9ind.dbhwmarkstatistics.sql
@&EXTRACTSDIR/dbinstances.sql
@&EXTRACTSDIR/dblinks.sql
@&EXTRACTSDIR/dbobjects.sql
@&EXTRACTSDIR/dbobjectnames.sql
@&EXTRACTSDIR/dbparameters.sql
@&EXTRACTSDIR/dbsummary.sql
@&EXTRACTSDIR/exttab.sql
@&EXTRACTSDIR/idxpertable.sql
@&EXTRACTSDIR/indextypes.sql
@&EXTRACTSDIR/indextypedtl.sql
@&EXTRACTSDIR/mviewtypes.sql
@&EXTRACTSDIR/opkeylog.sql
@&EXTRACTSDIR/sourcecode.sql
@&EXTRACTSDIR/dtlsourcecode.sql
@&EXTRACTSDIR/tablesnopk.sql
@&EXTRACTSDIR/tableconstraints.sql
@&EXTRACTSDIR/tabletypes.sql
@&EXTRACTSDIR/tabletypedtl.sql
@&EXTRACTSDIR/triggers.sql
@&EXTRACTSDIR/usedspacedetails.sql
@&EXTRACTSDIR/usrsegatt.sql
@&SQLDIR/&v_dopluggable
@&SQLDIR/op_collect_&v_dodiagnostics
@&EXTRACTSDIR/lobsizing.sql
--@&EXTRACTSDIR/opatch.sql
@&EXTRACTSDIR/eoj.sql

set termout on
prompt Step completed.
prompt
prompt Database Migration Assessment data successfully extracted.
prompt
exit
