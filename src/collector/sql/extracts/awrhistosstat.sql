spool &outputdir/opdb__awrhistosstat__&v_tag

WITH v_osstat_all
     AS (SELECT os.dbid,
                     os.instance_number,
                     TO_CHAR(os.begin_interval_time, 'hh24') hh24,
                     os.stat_name,
                     os.value cumulative_value,
                     os.delta_value,
                     ( TO_NUMBER(CAST(os.end_interval_time AS DATE) - CAST(os.begin_interval_time AS DATE)) * 60 * 60 * 24 )
                        snap_total_secs,
                     PERCENTILE_CONT(0.5)
                       within GROUP (ORDER BY os.delta_value DESC) over (
                         PARTITION BY os.dbid, os.instance_number,
                       TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS
                     "PERC50",
                     PERCENTILE_CONT(0.25)
                       within GROUP (ORDER BY os.delta_value DESC) over (
                         PARTITION BY os.dbid, os.instance_number,
                       TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS
                     "PERC75",
                     PERCENTILE_CONT(0.1)
                       within GROUP (ORDER BY os.delta_value DESC) over (
                         PARTITION BY os.dbid, os.instance_number,
                       TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS
                     "PERC90",
                     PERCENTILE_CONT(0.05)
                       within GROUP (ORDER BY os.delta_value DESC) over (
                         PARTITION BY os.dbid, os.instance_number,
                       TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS
                     "PERC95",
                     PERCENTILE_CONT(0)
                       within GROUP (ORDER BY os.delta_value DESC) over (
                         PARTITION BY os.dbid, os.instance_number,
                       TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS
                     "PERC100"
              FROM (SELECT snap.begin_interval_time, snap.end_interval_time, s.*,
                    NVL(DECODE(GREATEST(value, NVL(LAG(value)
                    OVER (
                    PARTITION BY s.dbid, s.instance_number, s.stat_name
                    ORDER BY s.snap_id), 0)), value, value - LAG(value)
                       OVER (
                       PARTITION BY s.dbid, s.instance_number, s.stat_name
                       ORDER BY s.snap_id),
                    0), 0) AS delta_value
                    FROM &v_tblprefix._hist_osstat s
                         inner join &v_tblprefix._hist_snapshot snap
                         ON s.snap_id = snap.snap_id
                         AND s.instance_number = snap.instance_number
                         AND s.dbid = snap.dbid
                    WHERE s.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
                    AND s.dbid = &&v_dbid) os ) ,
vossummary AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'        AS pkey,
       dbid,
       instance_number,
       hh24,
       stat_name,
       ROUND(SUM(snap_total_secs))       hh24_total_secs,
       ROUND(AVG(cumulative_value))      cumulative_value,
       ROUND(AVG(delta_value))           avg_value,
       ROUND(STATS_MODE(delta_value))    mode_value,
       ROUND(MEDIAN(delta_value))        median_value,
       ROUND(AVG(perc50))                PERC50,
       ROUND(AVG(perc75))                PERC75,
       ROUND(AVG(perc90))                PERC90,
       ROUND(AVG(perc95))                PERC95,
       ROUND(AVG(perc100))               PERC100,
       ROUND(MIN(delta_value))           min_value,
       ROUND(MAX(delta_value))           max_value,
       ROUND(SUM(delta_value))           sum_value,
       COUNT(1)             count
FROM   v_osstat_all
GROUP  BY '&&v_host'
          || '_'
          || '&&v_dbname'
          || '_'
          || '&&v_hora',
          dbid,
          instance_number,
          hh24,
          stat_name)
SELECT pkey , dbid , instance_number , hh24 , stat_name , hh24_total_secs ,
       cumulative_value , avg_value , mode_value , median_value , PERC50 , PERC75 , PERC90 , PERC95 , PERC100 ,
	     min_value , max_value , sum_value , count
FROM vossummary;
spool off
