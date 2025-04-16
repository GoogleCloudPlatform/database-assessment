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
spool &outputdir./opdb__defines__&s_tag.
@sql/extracts/defines.sql
spool off
spool &outputdir./opdb__archlogs__&s_tag.
@sql/extracts/archlogs.sql
spool off
spool &outputdir./opdb__users__&s_tag.
@sql/extracts/users.sql
spool off
@sql/extracts/&s_ora9ind.backups.sql
spool &outputdir./opdb__columntypes__&s_tag.
@sql/extracts/columntypes.sql
spool off
spool &outputdir./opdb__compressbytype__&s_tag.
-- @sql/extracts/compressbytype.sql
spool off
spool &outputdir./opdb__cpucoresusage__&s_tag.
@sql/extracts/&s_ora9ind.cpucoresusage.sql
spool off
spool &outputdir./opdb__dataguard__&s_tag.
@sql/extracts/dataguard.sql
spool off
spool &outputdir./opdb__datatypes__&s_tag.
@sql/extracts/datatypes.sql
spool off
spool &outputdir./opdb__dbfeatures__&s_tag.
@sql/extracts/&s_ora9ind.dbfeatures.sql
spool off
spool &outputdir./opdb__dbhwmarkstatistics__&s_tag.
@sql/extracts/&s_ora9ind.dbhwmarkstatistics.sql
spool off
spool &outputdir./opdb__dbinstances__&s_tag.
@sql/extracts/dbinstances.sql
spool off
spool &outputdir./opdb__dblinks__&s_tag.
@sql/extracts/dblinks.sql
spool off
spool &outputdir./opdb__dbobjects__&s_tag.
@sql/extracts/dbobjects.sql
spool off
spool &outputdir./opdb__dbobjectnames__&s_tag.
@sql/extracts/dbobjectnames.sql
spool off
spool &outputdir./opdb__dbparameters__&s_tag.
@sql/extracts/dbparameters.sql
spool off
spool &outputdir./opdb__dbsummary__&s_tag.
@sql/extracts/dbsummary.sql
spool off
spool &outputdir./opdb__exttab__&s_tag.
@sql/extracts/exttab.sql
spool off
spool &outputdir./opdb__idxpertable__&s_tag.
@sql/extracts/idxpertable.sql
spool off
spool &outputdir./opdb__indextypes__&s_tag.
@sql/extracts/indextypes.sql
spool off
spool &outputdir./opdb__indextypedtl__&s_tag.
@sql/extracts/indextypedtl.sql
spool off
spool &outputdir./opdb__mviewtypes__&s_tag.
@sql/extracts/mviewtypes.sql
spool off
spool &outputdir./opdb__opkeylog__&s_tag.
@sql/extracts/opkeylog.sql
spool off
spool &outputdir./opdb__sourcecode__&s_tag.
@sql/extracts/sourcecode.sql
spool off
spool &outputdir./opdb__dtlsourcecode__&s_tag.
@sql/extracts/dtlsourcecode.sql
spool off
spool &outputdir./opdb__tablesnopk__&s_tag.
@sql/extracts/tablesnopk.sql
spool off
spool &outputdir./opdb__tableconstraints__&s_tag.
@sql/extracts/tableconstraints.sql
spool off
spool &outputdir./opdb__tabletypes__&s_tag.
@sql/extracts/tabletypes.sql
spool off
spool &outputdir./opdb__tabletypedtl__&s_tag.
@sql/extracts/tabletypedtl.sql
spool off
spool &outputdir./opdb__triggers__&s_tag.
@sql/extracts/triggers.sql
spool off
spool &outputdir./opdb__usedspacedetails__&s_tag.
@sql/extracts/usedspacedetails.sql
spool off
spool &outputdir./opdb__usrsegatt__&s_tag.
@sql/extracts/usrsegatt.sql
spool off
@sql/&s_dopluggable.
@sql/op_collect_&s_useawr.
spool &outputdir./opdb__lobsizing__&s_tag.
@sql/extracts/lobsizing.sql
spool off
spool &outputdir./opdb__eoj__&s_tag.
@sql/extracts/eoj.sql
spool off

set termout on
prompt Step completed.
prompt
prompt Database Migration Assessment data successfully extracted.
prompt
exit
