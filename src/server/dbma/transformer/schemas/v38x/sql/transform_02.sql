/* 
 # Copyright 2022 Google LLC
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #     https://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 */
-- name: transform-02!
CREATE or REPLACE TABLE vsysstat_columnar (
        dbversion VARCHAR(10),
        metric_unit VARCHAR(100),
        info_source VARCHAR(100),
        pkey VARCHAR(100),
        dbid NUMERIC,
        instance_number NUMERIC,
        hour NUMERIC,
        cpu_used_by_this_session_perc50 NUMERIC,
        cpu_used_by_this_session_perc75 NUMERIC,
        cpu_used_by_this_session_perc95 NUMERIC,
        cpu_used_by_this_session_perc100 NUMERIC,
        dbtime_perc50 NUMERIC,
        dbtime_perc75 NUMERIC,
        dbtime_perc95 NUMERIC,
        dbtime_perc100 NUMERIC,
        cellflashcachereadhit_perc50 NUMERIC,
        cellflashcachereadhit_perc75 NUMERIC,
        cellflashcachereadhit_perc95 NUMERIC,
        cellflashcachereadhit_perc100 NUMERIC,
        cell_inter_bytes_returned_by_XT_smartscan_perc50 NUMERIC,
        cell_inter_bytes_returned_by_XT_smartscan_perc75 NUMERIC,
        cell_inter_bytes_returned_by_XT_smartscan_perc95 NUMERIC,
        cell_inter_bytes_returned_by_XT_smartscan_perc100 NUMERIC,
        cell_io_bytes_eligible_for_predicate_offload_perc50 NUMERIC,
        cell_io_bytes_eligible_for_predicate_offload_perc75 NUMERIC,
        cell_io_bytes_eligible_for_predicate_offload_perc95 NUMERIC,
        cell_io_bytes_eligible_for_predicate_offload_perc100 NUMERIC,
        cell_io_bytes_eligible_for_smartios_perc50 NUMERIC,
        cell_io_bytes_eligible_for_smartios_perc75 NUMERIC,
        cell_io_bytes_eligible_for_smartios_perc95 NUMERIC,
        cell_io_bytes_eligible_for_smartios_perc100 NUMERIC,
        cell_io_bytes_saved_by_storage_index_perc50 NUMERIC,
        cell_io_bytes_saved_by_storage_index_perc75 NUMERIC,
        cell_io_bytes_saved_by_storage_index_perc95 NUMERIC,
        cell_io_bytes_saved_by_storage_index_perc100 NUMERIC,
        cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc50 NUMERIC,
        cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc75 NUMERIC,
        cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc95 NUMERIC,
        cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc100 NUMERIC,
        cell_io_interconnect_bytes_perc50 NUMERIC,
        cell_io_interconnect_bytes_perc75 NUMERIC,
        cell_io_interconnect_bytes_perc95 NUMERIC,
        cell_io_interconnect_bytes_perc100 NUMERIC,
        cell_io_interconnect_bytes_returned_by_smartcan_perc50 NUMERIC,
        cell_io_interconnect_bytes_returned_by_smartcan_perc75 NUMERIC,
        cell_io_interconnect_bytes_returned_by_smartcan_perc95 NUMERIC,
        cell_io_interconnect_bytes_returned_by_smartcan_perc100 NUMERIC,
        cell_physical_write_io_bytes_eligible_for_offload_perc50 NUMERIC,
        cell_physical_write_io_bytes_eligible_for_offload_perc75 NUMERIC,
        cell_physical_write_io_bytes_eligible_for_offload_perc95 NUMERIC,
        cell_physical_write_io_bytes_eligible_for_offload_perc100 NUMERIC,
        cell_pmem_cache_read_hits_perc50 NUMERIC,
        cell_pmem_cache_read_hits_perc75 NUMERIC,
        cell_pmem_cache_read_hits_perc95 NUMERIC,
        cell_pmem_cache_read_hits_perc100 NUMERIC,
        dbblockgets_perc50 NUMERIC,
        dbblockgets_perc75 NUMERIC,
        dbblockgets_perc95 NUMERIC,
        execute_count_perc50 NUMERIC,
        execute_count_perc75 NUMERIC,
        execute_count_perc95 NUMERIC,
        execute_count_perc100 NUMERIC,
        physical_read_io_requests_perc50 NUMERIC,
        physical_read_io_requests_perc75 NUMERIC,
        physical_read_io_requests_perc95 NUMERIC,
        physical_read_io_requests_perc100 NUMERIC,
        physical_read_bytes_perc50 NUMERIC,
        physical_read_bytes_perc75 NUMERIC,
        physical_read_bytes_perc95 NUMERIC,
        physical_read_bytes_perc100 NUMERIC,
        physical_read_flash_cache_hits_perc50 NUMERIC,
        physical_read_flash_cache_hits_perc75 NUMERIC,
        physical_read_flash_cache_hits_perc95 NUMERIC,
        physical_read_flash_cache_hits_perc100 NUMERIC,
        physical_read_total_io_requests_perc50 NUMERIC,
        physical_read_total_io_requests_perc75 NUMERIC,
        physical_read_total_io_requests_perc95 NUMERIC,
        physical_read_total_io_requests_perc100 NUMERIC,
        physical_read_total_bytes_perc50 NUMERIC,
        physical_read_total_bytes_perc75 NUMERIC,
        physical_read_total_bytes_perc95 NUMERIC,
        physical_read_total_bytes_perc100 NUMERIC,
        physical_reads_perc50 NUMERIC,
        physical_reads_perc75 NUMERIC,
        physical_reads_perc95 NUMERIC,
        physical_reads_perc100 NUMERIC,
        physical_reads_direct_perc50 NUMERIC,
        physical_reads_direct_perc75 NUMERIC,
        physical_reads_direct_perc95 NUMERIC,
        physical_reads_direct_perc100 NUMERIC,
        physical_reads_direct_lob_perc50 NUMERIC,
        physical_reads_direct_lob_perc75 NUMERIC,
        physical_reads_direct_lob_perc95 NUMERIC,
        physical_reads_direct_lob_perc100 NUMERIC,
        physical_write_io_req_perc50 NUMERIC,
        physical_write_io_req_perc75 NUMERIC,
        physical_write_io_req_perc95 NUMERIC,
        physical_write_io_req_perc100 NUMERIC,
        physical_write_bytes_perc50 NUMERIC,
        physical_write_bytes_perc75 NUMERIC,
        physical_write_bytes_perc95 NUMERIC,
        physical_write_bytes_perc100 NUMERIC,
        physical_write_total_io_req_perc50 NUMERIC,
        physical_write_total_io_req_perc75 NUMERIC,
        physical_write_total_io_req_perc95 NUMERIC,
        physical_write_total_io_req_perc100 NUMERIC,
        physical_write_total_bytes_perc50 NUMERIC,
        physical_write_total_bytes_perc75 NUMERIC,
        physical_write_total_bytes_perc95 NUMERIC,
        physical_write_total_bytes_perc100 NUMERIC,
        physical_writes_perc50 NUMERIC,
        physical_writes_perc75 NUMERIC,
        physical_writes_perc95 NUMERIC,
        physical_writes_perc100 NUMERIC,
        physical_writes_direct_lob_perc50 NUMERIC,
        physical_writes_direct_lob_perc75 NUMERIC,
        physical_writes_direct_lob_perc95 NUMERIC,
        physical_writes_direct_lob_perc100 NUMERIC,
        recursive_cpu_usage_perc50 NUMERIC,
        recursive_cpu_usage_perc75 NUMERIC,
        recursive_cpu_usage_perc95 NUMERIC,
        recursive_cpu_usage_perc100 NUMERIC,
        user_io_wait_time_perc50 NUMERIC,
        user_io_wait_time_perc75 NUMERIC,
        user_io_wait_time_perc95 NUMERIC,
        user_io_wait_time_perc100 NUMERIC,
        user_calls_perc50 NUMERIC,
        user_calls_perc75 NUMERIC,
        user_calls_perc95 NUMERIC,
        user_calls_perc100 NUMERIC,
        user_commits_perc50 NUMERIC,
        user_commits_perc75 NUMERIC,
        user_commits_perc95 NUMERIC,
        user_commits_perc100 NUMERIC,
        user_rollbacks_perc50 NUMERIC,
        user_rollbacks_perc75 NUMERIC,
        user_rollbacks_perc95 NUMERIC,
        user_rollbacks_perc100 NUMERIC
    );


INSERT INTO vsysstat_columnar WITH v_dbahistsysstat as (
        select 'HIST_SYSSTAT' info_source,
            a.*,
            round(a.avg_value / b.avg_snaps_diff_secs, 1) avg_value_per_sec,
            round(a.mode_value / b.avg_snaps_diff_secs, 1) mode_value_per_sec,
            round(a.median_value / b.avg_snaps_diff_secs, 1) median_value_per_sec,
            round(a.perc50 / b.avg_snaps_diff_secs, 1) perc50_value_per_sec,
            round(a.perc75 / b.avg_snaps_diff_secs, 1) perc75_value_per_sec,
            round(a.perc90 / b.avg_snaps_diff_secs, 1) perc90_value_per_sec,
            round(a.perc95 / b.avg_snaps_diff_secs, 1) perc95_value_per_sec,
            round(a.perc100 / b.avg_snaps_diff_secs, 1) perc100_value_per_sec
        from dbahistsysstat a
            inner join awrsnapdetails b on a.pkey = b.pkey
            and a.dbid = b.dbid
            and a.instance_number = b.instance_number
            and a.hour = b.hour
    ),
    vsysstat_part1 as (
        select a.info_source,
            a.pkey,
            a.dbid,
            a.instance_number,
            a.hour,
            case
                when stat_name = 'CPU used by this session' then perc50_value_per_sec
            end cpu_used_by_this_session_perc50,
            case
                when stat_name = 'CPU used by this session' then perc75_value_per_sec
            end cpu_used_by_this_session_perc75,
            case
                when stat_name = 'CPU used by this session' then perc95_value_per_sec
            end cpu_used_by_this_session_perc95,
            case
                when stat_name = 'CPU used by this session' then perc100_value_per_sec
            end cpu_used_by_this_session_perc100,
            case
                when stat_name = 'DB time' then perc50_value_per_sec
            end dbtime_perc50,
            case
                when stat_name = 'DB time' then perc75_value_per_sec
            end dbtime_perc75,
            case
                when stat_name = 'DB time' then perc95_value_per_sec
            end dbtime_perc95,
            case
                when stat_name = 'DB time' then perc100_value_per_sec
            end dbtime_perc100,
            case
                when stat_name = 'cell flash cache read hits' then perc50_value_per_sec
            end cellflashcachereadhit_perc50,
            case
                when stat_name = 'cell flash cache read hits' then perc75_value_per_sec
            end cellflashcachereadhit_perc75,
            case
                when stat_name = 'cell flash cache read hits' then perc95_value_per_sec
            end cellflashcachereadhit_perc95,
            case
                when stat_name = 'cell flash cache read hits' then perc100_value_per_sec
            end cellflashcachereadhit_perc100,
            case
                when stat_name = 'cell interconnect bytes returned by XT smart scan' then perc50_value_per_sec
            end cell_inter_bytes_returned_by_XT_smartscan_perc50,
            case
                when stat_name = 'cell interconnect bytes returned by XT smart scan' then perc75_value_per_sec
            end cell_inter_bytes_returned_by_XT_smartscan_perc75,
            case
                when stat_name = 'cell interconnect bytes returned by XT smart scan' then perc95_value_per_sec
            end cell_inter_bytes_returned_by_XT_smartscan_perc95,
            case
                when stat_name = 'cell interconnect bytes returned by XT smart scan' then perc100_value_per_sec
            end cell_inter_bytes_returned_by_XT_smartscan_perc100,
            case
                when stat_name = 'cell physical IO bytes eligible for predicate offload' then perc50_value_per_sec
            end cell_io_bytes_eligible_for_predicate_offload_perc50,
            case
                when stat_name = 'cell physical IO bytes eligible for predicate offload' then perc75_value_per_sec
            end cell_io_bytes_eligible_for_predicate_offload_perc75,
            case
                when stat_name = 'cell physical IO bytes eligible for predicate offload' then perc95_value_per_sec
            end cell_io_bytes_eligible_for_predicate_offload_perc95,
            case
                when stat_name = 'cell physical IO bytes eligible for predicate offload' then perc100_value_per_sec
            end cell_io_bytes_eligible_for_predicate_offload_perc100,
            case
                when stat_name = 'cell physical IO bytes eligible for smart IOs' then perc50_value_per_sec
            end cell_io_bytes_eligible_for_smartios_perc50,
            case
                when stat_name = 'cell physical IO bytes eligible for smart IOs' then perc75_value_per_sec
            end cell_io_bytes_eligible_for_smartios_perc75,
            case
                when stat_name = 'cell physical IO bytes eligible for smart IOs' then perc95_value_per_sec
            end cell_io_bytes_eligible_for_smartios_perc95,
            case
                when stat_name = 'cell physical IO bytes eligible for smart IOs' then perc100_value_per_sec
            end cell_io_bytes_eligible_for_smartios_perc100,
            case
                when stat_name = 'cell physical IO bytes saved by storage index' then perc50_value_per_sec
            end cell_io_bytes_saved_by_storage_index_perc50,
            case
                when stat_name = 'cell physical IO bytes saved by storage index' then perc75_value_per_sec
            end cell_io_bytes_saved_by_storage_index_perc75,
            case
                when stat_name = 'cell physical IO bytes saved by storage index' then perc95_value_per_sec
            end cell_io_bytes_saved_by_storage_index_perc95,
            case
                when stat_name = 'cell physical IO bytes saved by storage index' then perc100_value_per_sec
            end cell_io_bytes_saved_by_storage_index_perc100,
            case
                when stat_name = 'cell physical IO bytes sent directly to DB node to balance CPU' then perc50_value_per_sec
            end cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc50,
            case
                when stat_name = 'cell physical IO bytes sent directly to DB node to balance CPU' then perc75_value_per_sec
            end cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc75,
            case
                when stat_name = 'cell physical IO bytes sent directly to DB node to balance CPU' then perc95_value_per_sec
            end cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc95,
            case
                when stat_name = 'cell physical IO bytes sent directly to DB node to balance CPU' then perc100_value_per_sec
            end cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc100,
            case
                when stat_name = 'cell physical IO interconnect bytes' then perc50_value_per_sec
            end cell_io_interconnect_bytes_perc50,
            case
                when stat_name = 'cell physical IO interconnect bytes' then perc75_value_per_sec
            end cell_io_interconnect_bytes_perc75,
            case
                when stat_name = 'cell physical IO interconnect bytes' then perc95_value_per_sec
            end cell_io_interconnect_bytes_perc95,
            case
                when stat_name = 'cell physical IO interconnect bytes' then perc100_value_per_sec
            end cell_io_interconnect_bytes_perc100,
            case
                when stat_name = 'cell physical IO interconnect bytes returned by smart scan' then perc50_value_per_sec
            end cell_io_interconnect_bytes_returned_by_smartcan_perc50,
            case
                when stat_name = 'cell physical IO interconnect bytes returned by smart scan' then perc75_value_per_sec
            end cell_io_interconnect_bytes_returned_by_smartcan_perc75,
            case
                when stat_name = 'cell physical IO interconnect bytes returned by smart scan' then perc95_value_per_sec
            end cell_io_interconnect_bytes_returned_by_smartcan_perc95,
            case
                when stat_name = 'cell physical IO interconnect bytes returned by smart scan' then perc100_value_per_sec
            end cell_io_interconnect_bytes_returned_by_smartcan_perc100,
            case
                when stat_name = 'cell physical write IO bytes eligible for offload' then perc50_value_per_sec
            end cell_physical_write_io_bytes_eligible_for_offload_perc50,
            case
                when stat_name = 'cell physical write IO bytes eligible for offload' then perc75_value_per_sec
            end cell_physical_write_io_bytes_eligible_for_offload_perc75,
            case
                when stat_name = 'cell physical write IO bytes eligible for offload' then perc95_value_per_sec
            end cell_physical_write_io_bytes_eligible_for_offload_perc95,
            case
                when stat_name = 'cell physical write IO bytes eligible for offload' then perc100_value_per_sec
            end cell_physical_write_io_bytes_eligible_for_offload_perc100,
            case
                when stat_name = 'cell pmem cache read hits' then perc50_value_per_sec
            end cell_pmem_cache_read_hits_perc50,
            case
                when stat_name = 'cell pmem cache read hits' then perc75_value_per_sec
            end cell_pmem_cache_read_hits_perc75,
            case
                when stat_name = 'cell pmem cache read hits' then perc95_value_per_sec
            end cell_pmem_cache_read_hits_perc95,
            case
                when stat_name = 'cell pmem cache read hits' then perc100_value_per_sec
            end cell_pmem_cache_read_hits_perc100,
            case
                when stat_name = 'db block gets' then perc50_value_per_sec
            end dbblockgets_perc50,
            case
                when stat_name = 'db block gets' then perc75_value_per_sec
            end dbblockgets_perc75,
            case
                when stat_name = 'db block gets' then perc95_value_per_sec
            end dbblockgets_perc95,
            case
                when stat_name = 'db block gets' then perc100_value_per_sec
            end dbblockgets_perc100,
            case
                when stat_name = 'execute count' then perc50_value_per_sec
            end execute_count_perc50,
            case
                when stat_name = 'execute count' then perc75_value_per_sec
            end execute_count_perc75,
            case
                when stat_name = 'execute count' then perc95_value_per_sec
            end execute_count_perc95,
            case
                when stat_name = 'execute count' then perc100_value_per_sec
            end execute_count_perc100,
            case
                when stat_name = 'physical read IO requests' then perc50_value_per_sec
            end physical_read_io_requests_perc50,
            case
                when stat_name = 'physical read IO requests' then perc75_value_per_sec
            end physical_read_io_requests_perc75,
            case
                when stat_name = 'physical read IO requests' then perc95_value_per_sec
            end physical_read_io_requests_perc95,
            case
                when stat_name = 'physical read IO requests' then perc100_value_per_sec
            end physical_read_io_requests_perc100,
            case
                when stat_name = 'physical read bytes' then perc50_value_per_sec
            end physical_read_bytes_perc50,
            case
                when stat_name = 'physical read bytes' then perc75_value_per_sec
            end physical_read_bytes_perc75,
            case
                when stat_name = 'physical read bytes' then perc95_value_per_sec
            end physical_read_bytes_perc95,
            case
                when stat_name = 'physical read bytes' then perc100_value_per_sec
            end physical_read_bytes_perc100,
            case
                when stat_name = 'physical read flash cache hits' then perc50_value_per_sec
            end physical_read_flash_cache_hits_perc50,
            case
                when stat_name = 'physical read flash cache hits' then perc75_value_per_sec
            end physical_read_flash_cache_hits_perc75,
            case
                when stat_name = 'physical read flash cache hits' then perc95_value_per_sec
            end physical_read_flash_cache_hits_perc95,
            case
                when stat_name = 'physical read flash cache hits' then perc100_value_per_sec
            end physical_read_flash_cache_hits_perc100,
            case
                when stat_name = 'physical read total IO requests' then perc50_value_per_sec
            end physical_read_total_io_requests_perc50,
            case
                when stat_name = 'physical read total IO requests' then perc75_value_per_sec
            end physical_read_total_io_requests_perc75,
            case
                when stat_name = 'physical read total IO requests' then perc95_value_per_sec
            end physical_read_total_io_requests_perc95,
            case
                when stat_name = 'physical read total IO requests' then perc100_value_per_sec
            end physical_read_total_io_requests_perc100,
            case
                when stat_name = 'physical read total bytes' then perc50_value_per_sec
            end physical_read_total_bytes_perc50,
            case
                when stat_name = 'physical read total bytes' then perc75_value_per_sec
            end physical_read_total_bytes_perc75,
            case
                when stat_name = 'physical read total bytes' then perc95_value_per_sec
            end physical_read_total_bytes_perc95,
            case
                when stat_name = 'physical read total bytes' then perc100_value_per_sec
            end physical_read_total_bytes_perc100,
            case
                when stat_name = 'physical reads' then perc50_value_per_sec
            end physical_reads_perc50,
            case
                when stat_name = 'physical reads' then perc75_value_per_sec
            end physical_reads_perc75,
            case
                when stat_name = 'physical reads' then perc95_value_per_sec
            end physical_reads_perc95,
            case
                when stat_name = 'physical reads' then perc100_value_per_sec
            end physical_reads_perc100,
            case
                when stat_name = 'physical reads direct' then perc50_value_per_sec
            end physical_reads_direct_perc50,
            case
                when stat_name = 'physical reads direct' then perc75_value_per_sec
            end physical_reads_direct_perc75,
            case
                when stat_name = 'physical reads direct' then perc95_value_per_sec
            end physical_reads_direct_perc95,
            case
                when stat_name = 'physical reads direct' then perc100_value_per_sec
            end physical_reads_direct_perc100,
            case
                when stat_name = 'physical reads direct (lob)' then perc50_value_per_sec
            end physical_reads_direct_lob_perc50,
            case
                when stat_name = 'physical reads direct (lob)' then perc75_value_per_sec
            end physical_reads_direct_lob_perc75,
            case
                when stat_name = 'physical reads direct (lob)' then perc95_value_per_sec
            end physical_reads_direct_lob_perc95,
            case
                when stat_name = 'physical reads direct (lob)' then perc100_value_per_sec
            end physical_reads_direct_lob_perc100,
            case
                when stat_name = 'physical write IO requests' then perc50_value_per_sec
            end physical_write_io_req_perc50,
            case
                when stat_name = 'physical write IO requests' then perc75_value_per_sec
            end physical_write_io_req_perc75,
            case
                when stat_name = 'physical write IO requests' then perc95_value_per_sec
            end physical_write_io_req_perc95,
            case
                when stat_name = 'physical write IO requests' then perc100_value_per_sec
            end physical_write_io_req_perc100,
            case
                when stat_name = 'physical write bytes' then perc50_value_per_sec
            end physical_write_bytes_perc50,
            case
                when stat_name = 'physical write bytes' then perc75_value_per_sec
            end physical_write_bytes_perc75,
            case
                when stat_name = 'physical write bytes' then perc95_value_per_sec
            end physical_write_bytes_perc95,
            case
                when stat_name = 'physical write bytes' then perc100_value_per_sec
            end physical_write_bytes_perc100,
            case
                when stat_name = 'physical write total IO requests' then perc50_value_per_sec
            end physical_write_total_io_req_perc50,
            case
                when stat_name = 'physical write total IO requests' then perc75_value_per_sec
            end physical_write_total_io_req_perc75,
            case
                when stat_name = 'physical write total IO requests' then perc95_value_per_sec
            end physical_write_total_io_req_perc95,
            case
                when stat_name = 'physical write total IO requests' then perc100_value_per_sec
            end physical_write_total_io_req_perc100,
            case
                when stat_name = 'physical write total bytes' then perc50_value_per_sec
            end physical_write_total_bytes_perc50,
            case
                when stat_name = 'physical write total bytes' then perc75_value_per_sec
            end physical_write_total_bytes_perc75,
            case
                when stat_name = 'physical write total bytes' then perc95_value_per_sec
            end physical_write_total_bytes_perc95,
            case
                when stat_name = 'physical write total bytes' then perc100_value_per_sec
            end physical_write_total_bytes_perc100,
            case
                when stat_name = 'physical writes' then perc50_value_per_sec
            end physical_writes_perc50,
            case
                when stat_name = 'physical writes' then perc75_value_per_sec
            end physical_writes_perc75,
            case
                when stat_name = 'physical writes' then perc95_value_per_sec
            end physical_writes_perc95,
            case
                when stat_name = 'physical writes' then perc100_value_per_sec
            end physical_writes_perc100,
            case
                when stat_name = 'physical writes direct (lob)' then perc50_value_per_sec
            end physical_writes_direct_lob_perc50,
            case
                when stat_name = 'physical writes direct (lob)' then perc75_value_per_sec
            end physical_writes_direct_lob_perc75,
            case
                when stat_name = 'physical writes direct (lob)' then perc95_value_per_sec
            end physical_writes_direct_lob_perc95,
            case
                when stat_name = 'physical writes direct (lob)' then perc100_value_per_sec
            end physical_writes_direct_lob_perc100,
            case
                when stat_name = 'recursive cpu usage' then perc50_value_per_sec
            end recursive_cpu_usage_perc50,
            case
                when stat_name = 'recursive cpu usage' then perc75_value_per_sec
            end recursive_cpu_usage_perc75,
            case
                when stat_name = 'recursive cpu usage' then perc95_value_per_sec
            end recursive_cpu_usage_perc95,
            case
                when stat_name = 'recursive cpu usage' then perc100_value_per_sec
            end recursive_cpu_usage_perc100,
            case
                when stat_name = 'user I/O wait time' then perc50_value_per_sec
            end user_io_wait_time_perc50,
            case
                when stat_name = 'user I/O wait time' then perc75_value_per_sec
            end user_io_wait_time_perc75,
            case
                when stat_name = 'user I/O wait time' then perc95_value_per_sec
            end user_io_wait_time_perc95,
            case
                when stat_name = 'user I/O wait time' then perc100_value_per_sec
            end user_io_wait_time_perc100,
            case
                when stat_name = 'user calls' then perc50_value_per_sec
            end user_calls_perc50,
            case
                when stat_name = 'user calls' then perc75_value_per_sec
            end user_calls_perc75,
            case
                when stat_name = 'user calls' then perc95_value_per_sec
            end user_calls_perc95,
            case
                when stat_name = 'user calls' then perc100_value_per_sec
            end user_calls_perc100,
            case
                when stat_name = 'user commits' then perc50_value_per_sec
            end user_commits_perc50,
            case
                when stat_name = 'user commits' then perc75_value_per_sec
            end user_commits_perc75,
            case
                when stat_name = 'user commits' then perc95_value_per_sec
            end user_commits_perc95,
            case
                when stat_name = 'user commits' then perc100_value_per_sec
            end user_commits_perc100,
            case
                when stat_name = 'user rollbacks' then perc50_value_per_sec
            end user_rollbacks_perc50,
            case
                when stat_name = 'user rollbacks' then perc75_value_per_sec
            end user_rollbacks_perc75,
            case
                when stat_name = 'user rollbacks' then perc95_value_per_sec
            end user_rollbacks_perc95,
            case
                when stat_name = 'user rollbacks' then perc100_value_per_sec
            end user_rollbacks_perc100
        from v_dbahistsysstat a
    ),
    vsysstat_part2 as (
        select b.info_source,
            b.pkey,
            b.dbid,
            b.instance_number,
            b.hour,
            sum(cpu_used_by_this_session_perc50) cpu_used_by_this_session_perc50,
            sum(cpu_used_by_this_session_perc75) cpu_used_by_this_session_perc75,
            sum(cpu_used_by_this_session_perc95) cpu_used_by_this_session_perc95,
            sum(cpu_used_by_this_session_perc100) cpu_used_by_this_session_perc100,
            sum(dbtime_perc50) dbtime_perc50,
            sum(dbtime_perc75) dbtime_perc75,
            sum(dbtime_perc95) dbtime_perc95,
            sum(dbtime_perc100) dbtime_perc100,
            sum(cellflashcachereadhit_perc50) cellflashcachereadhit_perc50,
            sum(cellflashcachereadhit_perc75) cellflashcachereadhit_perc75,
            sum(cellflashcachereadhit_perc95) cellflashcachereadhit_perc95,
            sum(cellflashcachereadhit_perc100) cellflashcachereadhit_perc100,
            sum(cell_inter_bytes_returned_by_XT_smartscan_perc50) cell_inter_bytes_returned_by_XT_smartscan_perc50,
            sum(cell_inter_bytes_returned_by_XT_smartscan_perc75) cell_inter_bytes_returned_by_XT_smartscan_perc75,
            sum(cell_inter_bytes_returned_by_XT_smartscan_perc95) cell_inter_bytes_returned_by_XT_smartscan_perc95,
            sum(
                cell_inter_bytes_returned_by_XT_smartscan_perc100
            ) cell_inter_bytes_returned_by_XT_smartscan_perc100,
            sum(
                cell_io_bytes_eligible_for_predicate_offload_perc50
            ) cell_io_bytes_eligible_for_predicate_offload_perc50,
            sum(
                cell_io_bytes_eligible_for_predicate_offload_perc75
            ) cell_io_bytes_eligible_for_predicate_offload_perc75,
            sum(
                cell_io_bytes_eligible_for_predicate_offload_perc95
            ) cell_io_bytes_eligible_for_predicate_offload_perc95,
            sum(
                cell_io_bytes_eligible_for_predicate_offload_perc100
            ) cell_io_bytes_eligible_for_predicate_offload_perc100,
            sum(cell_io_bytes_eligible_for_smartios_perc50) cell_io_bytes_eligible_for_smartios_perc50,
            sum(cell_io_bytes_eligible_for_smartios_perc75) cell_io_bytes_eligible_for_smartios_perc75,
            sum(cell_io_bytes_eligible_for_smartios_perc95) cell_io_bytes_eligible_for_smartios_perc95,
            sum(cell_io_bytes_eligible_for_smartios_perc100) cell_io_bytes_eligible_for_smartios_perc100,
            sum(cell_io_bytes_saved_by_storage_index_perc50) cell_io_bytes_saved_by_storage_index_perc50,
            sum(cell_io_bytes_saved_by_storage_index_perc75) cell_io_bytes_saved_by_storage_index_perc75,
            sum(cell_io_bytes_saved_by_storage_index_perc95) cell_io_bytes_saved_by_storage_index_perc95,
            sum(cell_io_bytes_saved_by_storage_index_perc100) cell_io_bytes_saved_by_storage_index_perc100,
            sum(
                cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc50
            ) cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc50,
            sum(
                cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc75
            ) cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc75,
            sum(
                cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc95
            ) cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc95,
            sum(
                cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc100
            ) cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc100,
            sum(cell_io_interconnect_bytes_perc50) cell_io_interconnect_bytes_perc50,
            sum(cell_io_interconnect_bytes_perc75) cell_io_interconnect_bytes_perc75,
            sum(cell_io_interconnect_bytes_perc95) cell_io_interconnect_bytes_perc95,
            sum(cell_io_interconnect_bytes_perc100) cell_io_interconnect_bytes_perc100,
            sum(
                cell_io_interconnect_bytes_returned_by_smartcan_perc50
            ) cell_io_interconnect_bytes_returned_by_smartcan_perc50,
            sum(
                cell_io_interconnect_bytes_returned_by_smartcan_perc75
            ) cell_io_interconnect_bytes_returned_by_smartcan_perc75,
            sum(
                cell_io_interconnect_bytes_returned_by_smartcan_perc95
            ) cell_io_interconnect_bytes_returned_by_smartcan_perc95,
            sum(
                cell_io_interconnect_bytes_returned_by_smartcan_perc100
            ) cell_io_interconnect_bytes_returned_by_smartcan_perc100,
            sum(
                cell_physical_write_io_bytes_eligible_for_offload_perc50
            ) cell_physical_write_io_bytes_eligible_for_offload_perc50,
            sum(
                cell_physical_write_io_bytes_eligible_for_offload_perc75
            ) cell_physical_write_io_bytes_eligible_for_offload_perc75,
            sum(
                cell_physical_write_io_bytes_eligible_for_offload_perc95
            ) cell_physical_write_io_bytes_eligible_for_offload_perc95,
            sum(
                cell_physical_write_io_bytes_eligible_for_offload_perc100
            ) cell_physical_write_io_bytes_eligible_for_offload_perc100,
            sum(cell_pmem_cache_read_hits_perc50) cell_pmem_cache_read_hits_perc50,
            sum(cell_pmem_cache_read_hits_perc75) cell_pmem_cache_read_hits_perc75,
            sum(cell_pmem_cache_read_hits_perc95) cell_pmem_cache_read_hits_perc95,
            sum(cell_pmem_cache_read_hits_perc100) cell_pmem_cache_read_hits_perc100,
            sum(dbblockgets_perc50) dbblockgets_perc50,
            sum(dbblockgets_perc75) dbblockgets_perc75,
            sum(dbblockgets_perc95) dbblockgets_perc95,
            sum(execute_count_perc50) execute_count_perc50,
            sum(execute_count_perc75) execute_count_perc75,
            sum(execute_count_perc95) execute_count_perc95,
            sum(execute_count_perc100) execute_count_perc100,
            sum(physical_read_io_requests_perc50) physical_read_io_requests_perc50,
            sum(physical_read_io_requests_perc75) physical_read_io_requests_perc75,
            sum(physical_read_io_requests_perc95) physical_read_io_requests_perc95,
            sum(physical_read_io_requests_perc100) physical_read_io_requests_perc100,
            sum(physical_read_bytes_perc50) physical_read_bytes_perc50,
            sum(physical_read_bytes_perc75) physical_read_bytes_perc75,
            sum(physical_read_bytes_perc95) physical_read_bytes_perc95,
            sum(physical_read_bytes_perc100) physical_read_bytes_perc100,
            sum(physical_read_flash_cache_hits_perc50) physical_read_flash_cache_hits_perc50,
            sum(physical_read_flash_cache_hits_perc75) physical_read_flash_cache_hits_perc75,
            sum(physical_read_flash_cache_hits_perc95) physical_read_flash_cache_hits_perc95,
            sum(physical_read_flash_cache_hits_perc100) physical_read_flash_cache_hits_perc100,
            sum(physical_read_total_io_requests_perc50) physical_read_total_io_requests_perc50,
            sum(physical_read_total_io_requests_perc75) physical_read_total_io_requests_perc75,
            sum(physical_read_total_io_requests_perc95) physical_read_total_io_requests_perc95,
            sum(physical_read_total_io_requests_perc100) physical_read_total_io_requests_perc100,
            sum(physical_read_total_bytes_perc50) physical_read_total_bytes_perc50,
            sum(physical_read_total_bytes_perc75) physical_read_total_bytes_perc75,
            sum(physical_read_total_bytes_perc95) physical_read_total_bytes_perc95,
            sum(physical_read_total_bytes_perc100) physical_read_total_bytes_perc100,
            sum(physical_reads_perc50) physical_reads_perc50,
            sum(physical_reads_perc75) physical_reads_perc75,
            sum(physical_reads_perc95) physical_reads_perc95,
            sum(physical_reads_perc100) physical_reads_perc100,
            sum(physical_reads_direct_perc50) physical_reads_direct_perc50,
            sum(physical_reads_direct_perc75) physical_reads_direct_perc75,
            sum(physical_reads_direct_perc95) physical_reads_direct_perc95,
            sum(physical_reads_direct_perc100) physical_reads_direct_perc100,
            sum(physical_reads_direct_lob_perc50) physical_reads_direct_lob_perc50,
            sum(physical_reads_direct_lob_perc75) physical_reads_direct_lob_perc75,
            sum(physical_reads_direct_lob_perc95) physical_reads_direct_lob_perc95,
            sum(physical_reads_direct_lob_perc100) physical_reads_direct_lob_perc100,
            sum(physical_write_io_req_perc50) physical_write_io_req_perc50,
            sum(physical_write_io_req_perc75) physical_write_io_req_perc75,
            sum(physical_write_io_req_perc95) physical_write_io_req_perc95,
            sum(physical_write_io_req_perc100) physical_write_io_req_perc100,
            sum(physical_write_bytes_perc50) physical_write_bytes_perc50,
            sum(physical_write_bytes_perc75) physical_write_bytes_perc75,
            sum(physical_write_bytes_perc95) physical_write_bytes_perc95,
            sum(physical_write_bytes_perc100) physical_write_bytes_perc100,
            sum(physical_write_total_io_req_perc50) physical_write_total_io_req_perc50,
            sum(physical_write_total_io_req_perc75) physical_write_total_io_req_perc75,
            sum(physical_write_total_io_req_perc95) physical_write_total_io_req_perc95,
            sum(physical_write_total_io_req_perc100) physical_write_total_io_req_perc100,
            sum(physical_write_total_bytes_perc50) physical_write_total_bytes_perc50,
            sum(physical_write_total_bytes_perc75) physical_write_total_bytes_perc75,
            sum(physical_write_total_bytes_perc95) physical_write_total_bytes_perc95,
            sum(physical_write_total_bytes_perc100) physical_write_total_bytes_perc100,
            sum(physical_writes_perc50) physical_writes_perc50,
            sum(physical_writes_perc75) physical_writes_perc75,
            sum(physical_writes_perc95) physical_writes_perc95,
            sum(physical_writes_perc100) physical_writes_perc100,
            sum(physical_writes_direct_lob_perc50) physical_writes_direct_lob_perc50,
            sum(physical_writes_direct_lob_perc75) physical_writes_direct_lob_perc75,
            sum(physical_writes_direct_lob_perc95) physical_writes_direct_lob_perc95,
            sum(physical_writes_direct_lob_perc100) physical_writes_direct_lob_perc100,
            sum(recursive_cpu_usage_perc50) recursive_cpu_usage_perc50,
            sum(recursive_cpu_usage_perc75) recursive_cpu_usage_perc75,
            sum(recursive_cpu_usage_perc95) recursive_cpu_usage_perc95,
            sum(recursive_cpu_usage_perc100) recursive_cpu_usage_perc100,
            sum(user_io_wait_time_perc50) user_io_wait_time_perc50,
            sum(user_io_wait_time_perc75) user_io_wait_time_perc75,
            sum(user_io_wait_time_perc95) user_io_wait_time_perc95,
            sum(user_io_wait_time_perc100) user_io_wait_time_perc100,
            sum(user_calls_perc50) user_calls_perc50,
            sum(user_calls_perc75) user_calls_perc75,
            sum(user_calls_perc95) user_calls_perc95,
            sum(user_calls_perc100) user_calls_perc100,
            sum(user_commits_perc50) user_commits_perc50,
            sum(user_commits_perc75) user_commits_perc75,
            sum(user_commits_perc95) user_commits_perc95,
            sum(user_commits_perc100) user_commits_perc100,
            sum(user_rollbacks_perc50) user_rollbacks_perc50,
            sum(user_rollbacks_perc75) user_rollbacks_perc75,
            sum(user_rollbacks_perc95) user_rollbacks_perc95,
            sum(user_rollbacks_perc100) user_rollbacks_perc100
        from vsysstat_part1 b
        group by b.info_source,
            b.pkey,
            b.dbid,
            b.instance_number,
            b.hour
    )
select d.db_version as dbversion,
    'All Metrics are Per Second' metric_unit,
    c.*
from vsysstat_part2 c
    inner join dbsummary d on c.pkey = d.pkey
    and c.dbid = d.dbid;