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
with db as (
  select db.oid as database_oid,
    db.datname as database_name,
    db.datcollate as database_collation,
    db.datconnlimit as max_connection_limit,
    db.datistemplate as is_template_database,
    pg_encoding_to_char(db.encoding) as character_set_encoding,
    pg_database_size(db.datname) as total_disk_size_bytes
  from pg_database db
  where datname = current_database()
),
db_size as (
  select s.datid as database_oid,
    s.datname as database_name,
    s.numbackends as backends_connected,
    s.xact_commit as txn_commit_count,
    s.xact_rollback as txn_rollback_count,
    s.blks_read as blocks_read_count,
    s.blks_hit as blocks_hit_count,
    s.tup_returned as tup_returned_count,
    s.tup_fetched as tup_fetched_count,
    s.tup_inserted as tup_inserted_count,
    s.tup_updated as tup_updated_count,
    s.tup_deleted as tup_deleted_count,
    s.conflicts as query_conflict_count,
    s.temp_files as temporary_file_count,
    s.temp_bytes as temporary_file_bytes_written,
    s.deadlocks as detected_deadlocks_count,
    s.checksum_failures as checksum_failure_count,
    s.checksum_last_failure as last_checksum_failure,
    s.blk_read_time as block_read_time_ms,
    s.blk_write_time as block_write_time_ms,
    s.session_time as session_time_ms,
    s.active_time as active_time_ms,
    s.idle_in_transaction_time as idle_in_transaction_time_ms,
    s.sessions as sessions_count,
    s.sessions_fatal as fatal_sessions_count,
    s.sessions_killed as killed_sessions_count,
    s.stats_reset statistics_last_reset_on
  from pg_stat_database s
),
src as (
  select db.database_oid,
    db.database_name,
    db.database_collation,
    db.max_connection_limit,
    db.is_template_database,
    db.character_set_encoding,
    db.total_disk_size_bytes,
    db_size.backends_connected,
    db_size.txn_commit_count,
    db_size.txn_rollback_count,
    db_size.blocks_read_count,
    db_size.blocks_hit_count,
    db_size.tup_returned_count,
    db_size.tup_fetched_count,
    db_size.tup_inserted_count,
    db_size.tup_updated_count,
    db_size.tup_deleted_count,
    db_size.query_conflict_count,
    db_size.temporary_file_count,
    db_size.temporary_file_bytes_written,
    db_size.detected_deadlocks_count,
    db_size.checksum_failure_count,
    db_size.last_checksum_failure,
    db_size.block_read_time_ms,
    db_size.block_write_time_ms,
    db_size.session_time_ms,
    db_size.active_time_ms,
    db_size.idle_in_transaction_time_ms,
    db_size.sessions_count,
    db_size.fatal_sessions_count,
    db_size.killed_sessions_count,
    db_size.statistics_last_reset_on
  from db
    join db_size on (db.database_oid = db_size.database_oid)
)
select chr(34) || :PKEY || chr(34) as pkey,
  chr(34) || :DMA_SOURCE_ID || chr(34) as dma_source_id,
  chr(34) || :DMA_MANUAL_ID || chr(34) as dma_manual_id,
  src.database_oid,
  src.database_name,
  chr(34) || version() || chr(34) as database_version,
  chr(34) || current_setting('server_version_num') || chr(34) as database_version_number,
  src.max_connection_limit,
  src.is_template_database,
  src.character_set_encoding,
  src.total_disk_size_bytes,
  src.backends_connected,
  src.txn_commit_count,
  src.txn_rollback_count,
  src.blocks_read_count,
  src.blocks_hit_count,
  src.tup_returned_count,
  src.tup_fetched_count,
  src.tup_inserted_count,
  src.tup_updated_count,
  src.tup_deleted_count,
  src.query_conflict_count,
  src.temporary_file_count,
  src.temporary_file_bytes_written,
  src.detected_deadlocks_count,
  src.checksum_failure_count,
  src.last_checksum_failure,
  src.block_read_time_ms,
  src.block_write_time_ms,
  src.session_time_ms,
  src.active_time_ms,
  src.idle_in_transaction_time_ms,
  src.sessions_count,
  src.fatal_sessions_count,
  src.killed_sessions_count,
  coalesce(
    to_char(
      statistics_last_reset_on,
      'YYYY-MM-DD HH24:MI:SS'
    ),
    '1970-01-01 00:00:00'
  ) as statistics_last_reset_on,
  inet_server_addr() as inet_server_addr,
  src.database_collation
from src;
