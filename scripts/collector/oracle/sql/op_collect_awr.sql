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
column t_sqlstats   new_value  s_sqlstats noprint

SELECT  CASE WHEN :v_dbversion LIKE '10%' OR  :v_dbversion = '111' THEN 'sql/extracts/awr/sqlstats111.sql' ELSE 'sql/extracts/awr/sqlstats.sql' END as t_sqlstats
FROM DUAL;

spool &outputdir./opdb__awrsnapdetails__&s_tag.
@sql/extracts/awr/awrsnapdetails.sql
spool off
spool &outputdir./opdb__awrhistcmdtypes__&s_tag.
@sql/extracts/awr/awrhistcmdtypes.sql
spool off
spool &outputdir./opdb__awrhistosstat__&s_tag.
@sql/extracts/awr/awrhistosstat.sql
spool off
spool &outputdir./opdb__awrhistsysmetrichist__&s_tag.
@sql/extracts/awr/awrhistsysmetrichist.sql
spool off
spool &outputdir./opdb__awrhistsysmetricsumm__&s_tag.
@sql/extracts/awr/awrhistsysmetricsumm.sql
spool off
spool &outputdir./opdb__dbahistsysstat__&s_tag.
@sql/extracts/awr/dbahistsysstat.sql
spool off
spool &outputdir./opdb__dbahistsystimemodel__&s_tag.
@sql/extracts/awr/dbahistsystimemodel.sql
spool off
spool &outputdir./opdb__ioevents__&s_tag.
@sql/extracts/awr/ioevents.sql
spool off
@sql/extracts/awr/&s_io_function_sql.
spool off
spool &outputdir./opdb__sourceconn__&s_tag.
@sql/extracts/awr/sourceconn.sql
spool off
spool &outputdir./opdb__sqlstats__&s_tag.
@&s_sqlstats.
spool off
