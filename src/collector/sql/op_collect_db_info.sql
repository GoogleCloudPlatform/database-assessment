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

set termout off
@&EXTRACTSDIR/archlogs.sql
@&EXTRACTSDIR/awrhistcmdtypes.sql
@&EXTRACTSDIR/awrhistosstat.sql
@&EXTRACTSDIR/awrhistsysmetrichist.sql
@&EXTRACTSDIR/awrhistsysmetricsumm.sql
@&EXTRACTSDIR/awrsnapdetails.sql
@&EXTRACTSDIR/backups.sql
@&EXTRACTSDIR/columntypes.sql
@&EXTRACTSDIR/compressbytype.sql
@&EXTRACTSDIR/cpucoresusage.sql
@&EXTRACTSDIR/dataguard.sql
@&EXTRACTSDIR/datatypes.sql
@&EXTRACTSDIR/dbahistsysstat.sql
@&EXTRACTSDIR/dbahistsystimemodel.sql
@&EXTRACTSDIR/dbfeatures.sql
@&EXTRACTSDIR/dbhwmarkstatistics.sql
@&EXTRACTSDIR/dbinstances.sql
@&EXTRACTSDIR/dblinks.sql
@&EXTRACTSDIR/dbobjects.sql
@&EXTRACTSDIR/dbparameters.sql
@&EXTRACTSDIR/dbsummary.sql
@&EXTRACTSDIR/exttab.sql
@&EXTRACTSDIR/idxpertable.sql
@&EXTRACTSDIR/indexestypes.sql
@&EXTRACTSDIR/ioevents.sql
@&EXTRACTSDIR/iofunction.sql
@&EXTRACTSDIR/opkeylog.sql
@&EXTRACTSDIR/sourcecode.sql
@&EXTRACTSDIR/sourceconn.sql
@&EXTRACTSDIR/sqlstats.sql
@&EXTRACTSDIR/tablesnopk.sql
@&EXTRACTSDIR/usedspacedetails.sql
@&EXTRACTSDIR/usrsegatt.sql
@&SQLDIR/&v_dopluggable
