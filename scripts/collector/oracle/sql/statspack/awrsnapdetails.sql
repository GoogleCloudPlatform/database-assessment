spool &outputdir/opdb__awrsnapdetails__&v_tag

WITH vawrsnap as (
SELECT  '&&v_host'
        || '_'
        || '&&v_dbname'
        || '_'
        || '&&v_hora'                                                            AS pkey,
        dbid, instance_number, hour,
        min(snap_id) min_snap_id, max(snap_id) max_snap_id,
        TO_CHAR(min(snap_time), 'YYYY-MM-DD HH24:MI:SS') min_begin_interval_time, 
        TO_CHAR(max(snap_time), 'YYYY-MM-DD HH24:MI:SS') max_begin_interval_time,
        count(1) cnt,ROUND(SUM(snaps_diff_secs),0) sum_snaps_diff_secs,
        ROUND(avg(snaps_diff_secs),0) avg_snaps_diff_secs,
        ROUND(median(snaps_diff_secs),0) median_snaps_diff_secs,
        ROUND(STATS_MODE(snaps_diff_secs),0) mode_snaps_diff_secs,
        ROUND(min(snaps_diff_secs),0) min_snaps_diff_secs,
        ROUND(max(snaps_diff_secs),0) max_snaps_diff_secs
FROM (
        SELECT snap_id,
               dbid,
               instance_number,
               snap_time,
               hour,
               snaps_diff_secs
        FROM (
		SELECT
		       s.snap_id,
		       s.dbid,
		       s.instance_number,
		       s.snap_time,
		       TO_CHAR(s.snap_time,'hh24') hour,
		       NVL(DECODE(GREATEST(snap_time, NVL(LAG(snap_time)
							over (
							  PARTITION BY s.dbid, s.instance_number
							  ORDER BY s.snap_id), SYSDATE)), snap_time, snap_time - LAG(snap_time)
												     over (
												       PARTITION BY s.dbid, s.instance_number
												       ORDER BY s.snap_id),
										    0), 0) * 60 * 60 * 24 AS snaps_diff_secs,
                       s.startup_time,
                       LAG(s.startup_time,1) OVER (partition by instance_number ORDER BY snap_time) as lag_startup_time
		FROM   STATS$SNAPSHOT s
		WHERE  s.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
		AND dbid = &&v_dbid
		order by s.snap_id )
        WHERE startup_time = lag_startup_time
        )
GROUP BY '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora', dbid, instance_number, hour)
SELECT pkey , dbid , instance_number , hour , min_snap_id , max_snap_id , min_begin_interval_time ,
       max_begin_interval_time , cnt , sum_snaps_diff_secs , avg_snaps_diff_secs , median_snaps_diff_secs ,
       mode_snaps_diff_secs , min_snaps_diff_secs , max_snaps_diff_secs
FROM vawrsnap;

spool off

