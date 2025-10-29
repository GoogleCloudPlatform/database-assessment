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
column hour format a4
spool &outputdir/opdb__ioevents__&v_tag
prompt PKEY|DBID|INSTANCE_NUMBER|HOUR|WAIT_CLASS|EVENT_NAME|TOT_WAITS_DELTA_VALUE_P95|TOT_TOUT_DELTA_VALUE_P95|TIME_WA_US_DELTA_VALUE_P95|TOT_WAITS_DELTA_VALUE_P100|TOT_TOUT_DELTA_VALUE_P100|TIME_WA_US_DELTA_VALUE_P100|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vrawev AS (
SELECT :v_pkey AS pkey,
       sev.dbid,
       sev.instance_number,
       dhsnap.begin_interval_time,
       to_char(dhsnap.begin_interval_time,'hh24') hour,
       sev.wait_class,
       sev.event_name,
       sev.total_waits,
       NVL(DECODE(GREATEST(sev.total_waits, NVL(LAG(sev.total_waits)
                                                         OVER (PARTITION BY sev.dbid, sev.instance_number, sev.event_name ORDER BY sev.snap_id), 0)),
                  sev.total_waits, sev.total_waits - LAG(sev.total_waits)
                                                                       OVER (PARTITION BY sev.dbid, sev.instance_number, sev.event_name ORDER BY sev.snap_id),0), 0) AS tot_waits_delta_value,
       sev.total_timeouts,
       NVL(DECODE(GREATEST(sev.total_timeouts, NVL(LAG(sev.total_timeouts)
                                                        OVER (PARTITION BY sev.dbid, sev.instance_number, sev.event_name ORDER BY sev.snap_id), 0)),
                  sev.total_timeouts, sev.total_timeouts - LAG(sev.total_timeouts)
                                                                      OVER (PARTITION BY sev.dbid, sev.instance_number, sev.event_name ORDER BY sev.snap_id),0), 0) AS tot_tout_delta_value,
       sev.time_waited_micro,
       NVL(DECODE(GREATEST(sev.time_waited_micro, NVL(LAG(sev.time_waited_micro)
                                                        OVER (PARTITION BY sev.dbid, sev.instance_number, sev.event_name ORDER BY sev.snap_id), 0)),
                  sev.time_waited_micro, sev.time_waited_micro - LAG(sev.time_waited_micro)
                                                                      OVER (PARTITION BY sev.dbid, sev.instance_number, sev.event_name ORDER BY sev.snap_id),0), 0) AS time_wa_us_delta_value
FROM &v_tblprefix._HIST_SYSTEM_EVENT sev
     INNER JOIN &v_tblprefix._HIST_SNAPSHOT dhsnap
     ON sev.snap_id = dhsnap.snap_id
     AND sev.instance_number = dhsnap.instance_number
     AND sev.dbid = dhsnap.dbid
WHERE  sev.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
AND sev.dbid = &&v_dbid
AND sev.wait_class IN ('User I/O', 'System I/O', 'Commit')),
vpercev AS(
SELECT pkey,
       dbid,
       instance_number,
       hour,
       wait_class,
       event_name,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY tot_waits_delta_value DESC) AS tot_waits_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY tot_tout_delta_value DESC) AS tot_tout_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY time_wa_us_delta_value DESC) AS time_wa_us_delta_value_P95,
       PERCENTILE_CONT(0.00)
         within GROUP (ORDER BY tot_waits_delta_value DESC) AS tot_waits_delta_value_P100,
       PERCENTILE_CONT(0.00)
         within GROUP (ORDER BY tot_tout_delta_value DESC) AS tot_tout_delta_value_P100,
       PERCENTILE_CONT(0.00)
         within GROUP (ORDER BY time_wa_us_delta_value DESC) AS time_wa_us_delta_value_P100
FROM vrawev
GROUP BY pkey,
         dbid,
         instance_number,
         hour,
         wait_class,
         event_name),
vfev as(
SELECT pkey,
       dbid,
       instance_number,
       hour,
       wait_class,
       event_name,
       ROUND(tot_waits_delta_value_P95) tot_waits_delta_value_P95,
       ROUND(tot_tout_delta_value_P95) tot_tout_delta_value_P95,
       ROUND(time_wa_us_delta_value_P95) time_wa_us_delta_value_P95,
       ROUND(tot_waits_delta_value_P100) tot_waits_delta_value_P100,
       ROUND(tot_tout_delta_value_P100) tot_tout_delta_value_P100,
       ROUND(time_wa_us_delta_value_P100) time_wa_us_delta_value_P100
FROM vpercev)
SELECT pkey , dbid , instance_number , hour , wait_class , event_name ,
       tot_waits_delta_value_P95 ,
       tot_tout_delta_value_P95 ,
       time_wa_us_delta_value_P95,
       tot_waits_delta_value_P100 ,
       tot_tout_delta_value_P100 ,
       time_wa_us_delta_value_P100,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vfev;
spool off
column hour clear
