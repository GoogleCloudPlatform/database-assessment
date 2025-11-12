-- IOPS series
-- TODO Need to compute delta value
select :v_pkey  || '|' ||
       s.begin_interval_time || '|' ||
       dhs.snap_id || '|' ||
       dhs.instance_number || '|' ||
       SUM(CASE WHEN stat_name = 'physical read total IO requests' THEN value ELSE 0 END) || '|' || --read_reqs 
       SUM(CASE WHEN stat_name IN ('physical write total IO requests', 'redo writes') THEN value ELSE 0 END) || '|' || --write_reqs 
       SUM(CASE WHEN stat_name = 'physical read total bytes' THEN value ELSE 0 END) || '|' || --read_bytes 
       SUM(CASE WHEN stat_name IN ('physical write total bytes', 'redo size') THEN value ELSE 0 END) || '|' || --write_bytes 
       :v_dma_source_id || '|' || --dma_source_id  
       :v_manual_unique_id --dma_manual_id
From &s_tblprefix._HIST_SYSSTAT dhs
join &s_tblprefix._hist_snapshot s
        on s.snap_Id = dhs.snap_id
        and s.instance_number = dhs.instance_number
       AND s.snap_id BETWEEN :v_min_snapid AND :v_max_snapid
       AND s.dbid = :v_dbid
       AND s.dbid = dhs.dbid
group by s.begin_interval_time, dhs.snap_id, dhs.instance_number
;
