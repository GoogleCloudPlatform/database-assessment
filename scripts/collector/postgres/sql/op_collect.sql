/*
 Copyright 2024 Google LLC

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
\i sql/init.sql

\o output/opdb__pg_applications_:VTAG.csv
\i sql/applications.sql
\o

\o output/opdb__pg_aws_extension_dependency_:VTAG.csv
\i sql/aws_extension_dependency.sql
\o

\o output/opdb__pg_aws_oracle_exists_:VTAG.csv
\i sql/aws_oracle_exists.sql
\o

--\o output/opdb__pg_aws_oracle_version_:VTAG.csv
--\i sql/aws_oracle_version.sql
--\o

\o output/opdb__pg_bg_writer_stats_:VTAG.csv
\i sql/bg_writer_stats.sql
\o

\o output/opdb__pg_database_details_:VTAG.csv
\i sql/:VPGVERSION/database_details.sql
\o

\o output/opdb__pg_data_types_:VTAG.csv
\i sql/data_types.sql
\o

\o output/opdb__pg_extensions_:VTAG.csv
\i sql/extensions.sql
\o

\o output/opdb__pg_index_details_:VTAG.csv
\i sql/index_details.sql
\o

\o output/opdb__pg_replication_slots_:VTAG.csv
\i sql/:VPGVERSION/replication_slots.sql
\o

\o output/opdb__pg_replication_stats_:VTAG.csv
\i sql/replication_stats.sql
\o

\o output/opdb__pg_settings_:VTAG.csv
\i sql/settings.sql
\o

\o output/opdb__pg_schema_objects_:VTAG.csv
\i sql/schema_objects.sql
\o

\o output/opdb__pg_schema_details_:VTAG.csv
\i sql/schema_details.sql
\o

\o output/opdb__pg_settings_:VTAG.csv
\i sql/settings.sql
\o

\o output/opdb__pg_table_details_:VTAG.csv
\i sql/:VPGVERSION/table_details.sql
\o

\o output/opdb__pg_source_details_:VTAG.csv
\i sql/source_details.sql
\o

\o output/opdb__pg_calculated_metrics_:VTAG.csv
\i sql/calculated_metrics.sql
\o
