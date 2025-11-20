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
column t_sqlstats   new_value  v_sqlstats noprint

SELECT  CASE WHEN '&v_dbversion' LIKE '10%' OR  '&v_dbversion' = '111' THEN '&AWRDIR/sqlstats111.sql' ELSE '&AWRDIR/sqlstats.sql' END as t_sqlstats
FROM DUAL;

@&AWRDIR/awrsnapdetails.sql
@&AWRDIR/awrhistcmdtypes.sql
@&AWRDIR/awrhistosstat.sql
@&AWRDIR/awrhistsysmetrichist.sql
@&AWRDIR/awrhistsysmetricsumm.sql
@&AWRDIR/dbahistsysstat.sql
@&AWRDIR/dbahistsystimemodel.sql
@&AWRDIR/ioevents.sql
--@&AWRDIR/iofunction.sql
@&AWRDIR/&v_io_function_sql
@&AWRDIR/sourceconn.sql
@&v_sqlstats
