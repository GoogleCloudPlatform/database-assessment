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

spool &outputdir./opdb__awrsnapdetails__&s_tag.
@sql/extracts/statspack/awrsnapdetails.sql
spool off
spool &outputdir./opdb__awrhistcmdtypes__&s_tag.
@sql/extracts/statspack/awrhistcmdtypes.sql
spool off
spool &outputdir./opdb__awrhistosstat__&s_tag.
@sql/extracts/statspack/awrhistosstat.sql
spool off
spool &outputdir./opdb__awrhistsysmetrichist__&s_tag.
@sql/extracts/statspack/awrhistsysmetrichist.sql
spool off
spool &outputdir./opdb__awrhistsysmetricsumm__&s_tag.
@sql/extracts/statspack/awrhistsysmetricsumm.sql
spool off
spool &outputdir./opdb__dbahistsysstat__&s_tag.
@sql/extracts/statspack/dbahistsysstat.sql
spool off
spool &outputdir./opdb__dbahistsystimemodel__&s_tag.
@sql/extracts/statspack/dbahistsystimemodel.sql
spool off
spool &outputdir./opdb__ioevents__&s_tag.
@sql/extracts/statspack/ioevents.sql
spool off
spool &outputdir./opdb__iofunction__&s_tag.
PROMPT s_io_function = &s_io_function_sql. 
@sql/extracts/statspack/&s_io_function_sql.
spool off
spool &outputdir./opdb__sqlstats__&s_tag.
@sql/extracts/statspack/sqlstats.sql
spool off
