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
--name: transform-03!
CREATE or replace TABLE T_DS_CPU_CALC AS WITH hostdetails AS (
        SELECT TRIM(dbinstances.pkey) AS PKEY,
            dbinstances.host_name as host_name,
            CAST(metrics.INSTANCE_NUMBER AS BIGINT) AS instanceNumber,
            MAX(
                CAST(
                    metrics.NUM_CPU_CORES_CUMULATIVE_VALUE AS DECIMAL
                )
            ) AS cores,
            MAX(
                CAST(
                    metrics.PHYSICAL_MEMORY_BYTES_CUMULATIVE_VALUE AS DECIMAL
                ) / 1024 / 1024 / 1024
            ) AS totalMemoryGB
        FROM awrhistosstat_rs AS metrics
            INNER JOIN dbinstances AS dbinstances ON TRIM(metrics.PKEY) = TRIM(dbinstances.pkey)
            AND CAST(metrics.INSTANCE_NUMBER AS BIGINT) = CAST(dbinstances.inst_id AS BIGINT)
        GROUP BY dbinstances.pkey,
            dbinstances.host_name,
            instanceNumber
    ),
    vcputimemodel as (
        SELECT pkey,
            dbid,
            instance_number,
            hour,
            AVG(DB_CPU_PERC95) DB_CPU_PERC95,
            AVG(BACKG_CPU_TIME_PERC95) BACKG_CPU_TIME_PERC95,
            AVG(DB_TIME_PERC95) DB_TIME_PERC95,
            AVG(SQL_EXEC_ELAPS_TIME_PERC95) SQL_EXEC_ELAPS_TIME_PERC95
        FROM (
                SELECT pkey,
                    dbid,
                    instance_number,
                    hour,
                    PERCENTILE_CONT(0.95) WITHIN GROUP (
                        ORDER BY DB_CPU_PERC95
                    ) AS DB_CPU_PERC95,
                    /*OVER(partition by pkey, dbid, instance_number, hour) */
                    PERCENTILE_CONT(0.95) WITHIN GROUP (
                        ORDER BY BACKG_CPU_TIME_PERC95
                    ) AS BACKG_CPU_TIME_PERC95,
                    -- OVER(partition by pkey, dbid, instance_number, hour) AS BACKG_CPU_TIME_PERC95,
                    PERCENTILE_CONT(0.95) WITHIN GROUP (
                        ORDER BY DB_TIME_PERC95
                    ) AS DB_TIME_PERC95,
                    -- OVER(partition by pkey, dbid, instance_number, hour) AS DB_TIME_PERC95,
                    PERCENTILE_CONT(0.95) WITHIN GROUP (
                        ORDER BY SQL_EXEC_ELAPS_TIME_PERC95
                    ) AS SQL_EXEC_ELAPS_TIME_PERC95 -- OVER(partition by pkey, dbid, instance_number, hour) AS SQL_EXEC_ELAPS_TIME_PERC95
                FROM (
                        SELECT pkey,
                            dbid,
                            instance_number,
                            hour,
                            CASE
                                WHEN trim(a.stat_name) = 'DB CPU' then perc95
                            END DB_CPU_PERC95,
                            CASE
                                WHEN trim(a.stat_name) = 'background cpu time' then perc95
                            END BACKG_CPU_TIME_PERC95,
                            CASE
                                WHEN trim(a.stat_name) = 'DB time' then perc95
                            END DB_TIME_PERC95,
                            CASE
                                WHEN trim(a.stat_name) = 'sql execute elapsed time' then perc95
                            END SQL_EXEC_ELAPS_TIME_PERC95
                        FROM dbahistsystimemodel a
                        WHERE TRIM(a.stat_name) IN (
                                'DB CPU',
                                'background cpu time',
                                'DB time',
                                'sql execute elapsed time'
                            )
                    ) s1
                GROUP BY pkey,
                    dbid,
                    instance_number,
                    hour
            ) s2
        GROUP BY pkey,
            dbid,
            instance_number,
            hour
    ),
    vcpusysstat AS (
        SELECT pkey,
            dbid,
            instance_number,
            hour,
            AVG(RECURSIVE_CPU_PERC95) RECURSIVE_CPU_PERC95,
            AVG(PARSE_CPU_PERC95) PARSE_CPU_PERC95
        FROM (
                SELECT pkey,
                    dbid,
                    instance_number,
                    hour,
                    PERCENTILE_CONT(0.95) WITHIN GROUP (
                        ORDER BY RECURSIVE_CPU_PERC95
                    ) AS RECURSIVE_CPU_PERC95,
                    -- OVER(partition by pkey, dbid, instance_number, hour) AS RECURSIVE_CPU_PERC95,
                    PERCENTILE_CONT(0.95) WITHIN GROUP (
                        ORDER BY PARSE_CPU_PERC95
                    ) AS PARSE_CPU_PERC95 -- OVER(partition by pkey, dbid, instance_number, hour) AS PARSE_CPU_PERC95
                FROM (
                        SELECT pkey,
                            dbid,
                            instance_number,
                            hour,
                            CASE
                                WHEN trim(a.stat_name) = 'recursive cpu usage' then (round(cast(PERC95 as numeric), 2))
                            END RECURSIVE_CPU_PERC95,
                            CASE
                                WHEN trim(a.stat_name) = 'parse time cpu' then round(cast(PERC95 as numeric), 2)
                            END PARSE_CPU_PERC95
                        FROM dbahistsysstat a -- << VIEW
                        WHERE TRIM(a.stat_name) IN ('recursive cpu usage', 'parse time cpu')
                    ) s3
                GROUP BY pkey,
                    dbid,
                    instance_number,
                    hour
            ) s4
        GROUP BY pkey,
            dbid,
            instance_number,
            hour
    ),
    vcpuosstat AS (
        SELECT pkey,
            dbid,
            instance_number,
            hour,
            AVG(NUM_CPU_CORES_PERC95) NUM_CPU_CORES_PERC95,
            AVG(NUM_CPUS_PERC95) NUM_CPUS_PERC95,
            AVG(BUSY_TIME_PERC95) BUSY_TIME_PERC95,
            AVG(IDLE_TIME_PERC95) IDLE_TIME_PERC95
        FROM (
                SELECT pkey,
                    dbid,
                    instance_number,
                    hour,
                    PERCENTILE_CONT(0.95) WITHIN GROUP (
                        ORDER BY NUM_CPU_CORES
                    ) AS NUM_CPU_CORES_PERC95,
                    --OVER(partition by pkey, dbid, instance_number, hour) AS NUM_CPU_CORES_PERC95,
                    PERCENTILE_CONT(0.95) WITHIN GROUP (
                        ORDER BY NUM_CPUS
                    ) AS NUM_CPUS_PERC95,
                    --OVER(partition by pkey, dbid, instance_number, hour) AS NUM_CPUS_PERC95,
                    PERCENTILE_CONT(0.95) WITHIN GROUP (
                        ORDER BY BUSY_TIME
                    ) AS BUSY_TIME_PERC95,
                    --OVER(partition by pkey, dbid, instance_number, hour) AS BUSY_TIME_PERC95,
                    PERCENTILE_CONT(0.95) WITHIN GROUP (
                        ORDER BY IDLE_TIME
                    ) AS IDLE_TIME_PERC95 --OVER(partition by pkey, dbid, instance_number, hour) AS IDLE_TIME_PERC95
                FROM (
                        SELECT pkey,
                            dbid,
                            instance_number,
                            hh24 as hour,
                            CASE
                                WHEN trim(a.stat_name) = 'NUM_CPU_CORES' then cast(CUMULATIVE_VALUE as numeric)
                            END NUM_CPU_CORES,
                            CASE
                                WHEN trim(a.stat_name) = 'NUM_CPUS' then cast(CUMULATIVE_VALUE as numeric)
                            END NUM_CPUS,
                            CASE
                                WHEN trim(a.stat_name) = 'BUSY_TIME' then cast(perc95 as numeric)
                            END BUSY_TIME,
                            CASE
                                WHEN trim(a.stat_name) = 'IDLE_TIME' then cast(perc95 as numeric)
                            END IDLE_TIME
                        FROM awrhistosstat a
                        WHERE TRIM(a.stat_name) IN (
                                'NUM_CPU_CORES',
                                'NUM_CPUS',
                                'BUSY_TIME',
                                'IDLE_TIME'
                            )
                    ) s5
                GROUP BY pkey,
                    dbid,
                    instance_number,
                    hour
            ) s6
        GROUP BY pkey,
            dbid,
            instance_number,
            hour
    ),
    vhandlingzeroCPU AS (
        SELECT tm.pkey,
            tm.dbid,
            tm.instance_number,
            tm.hour,
            ROUND((CAST (DB_CPU_PERC95 AS NUMERIC) / 1000000), 2) DB_CPU_P95_SECONDS,
            ROUND(
                (
                    CAST (BACKG_CPU_TIME_PERC95 AS NUMERIC) / 1000000
                ),
                2
            ) BACKG_CPU_TIME_P95_SECONDS,
            ROUND(
                (CAST (RECURSIVE_CPU_PERC95 AS NUMERIC) / 100),
                2
            ) RECURSIVE_CPU_P95_SECONDS,
            ROUND((CAST (PARSE_CPU_PERC95 AS NUMERIC) / 100), 2) PARSE_CPU_P95_SECONDS,
            ROUND((cast (BUSY_TIME_PERC95 as numeric)) / 100, 2) OS_BUSY_TIME_P95_SECONDS,
            ROUND((cast (IDLE_TIME_PERC95 as numeric)) / 100, 2) OS_IDLE_TIME_P95_SECONDS,
            ROUND(
                (
                    (
                        CAST (DB_CPU_PERC95 AS NUMERIC) / 1000000 + (CAST (BACKG_CPU_TIME_PERC95 AS NUMERIC)) / 1000000
                    ) * 100
                ) / (
                    cast(BUSY_TIME_PERC95 as numeric) / 100 + cast(IDLE_TIME_PERC95 as numeric) / 100
                ),
                2
            ) DB_CPU_USAGE_PERCENTAGE,
            ROUND(
                ((cast(BUSY_TIME_PERC95 as numeric) / 100) * 100) /(
                    cast(BUSY_TIME_PERC95 as numeric) / 100 + cast(IDLE_TIME_PERC95 as numeric) / 100
                ),
                2
            ) HOST_CPU_USAGE_PERCENTAGE,
            NUM_CPU_CORES_PERC95,
            NUM_CPUS_PERC95,
            ROUND(
                (
                    cast(BUSY_TIME_PERC95 as numeric) / 100 + cast(IDLE_TIME_PERC95 as numeric) / 100
                ) / cast(avg_snaps_diff_secs AS NUMERIC)
            ) NUM_CPU_CORES_CALC_RVENG
        FROM vcputimemodel tm
            INNER JOIN vcpusysstat st ON tm.pkey = st.pkey
            AND tm.dbid = st.dbid
            AND tm.instance_number = st.instance_number
            AND tm.hour = st.hour
            INNER JOIN vcpuosstat os ON trim(tm.pkey) = trim(os.pkey)
            AND CAST(tm.dbid AS NUMERIC) = CAST(os.dbid AS NUMERIC)
            AND CAST(tm.instance_number AS NUMERIC) = CAST(os.instance_number AS NUMERIC)
            AND CAST(tm.hour AS NUMERIC) = CAST(os.hour AS NUMERIC)
            INNER JOIN awrsnapdetails snp ON tm.pkey = snp.pkey
            AND tm.dbid = CAST(snp.dbid AS numeric)
            AND tm.instance_number = CAST(snp.instance_number AS numeric)
            AND CAST(tm.hour AS NUMERIC) = CAST(snp.hour AS numeric)
        ORDER BY tm.pkey,
            tm.dbid,
            tm.instance_number,
            tm.hour
    ),
    DBCPU AS (
        SELECT b.host_name,
            round(max((b.DB_CPU_CORES) * 1.1) + 1, 2) as DB_CPU_CORES,
            --uplifted the DB CPU 10% to account for growth and added one additional core for the OS
            ROUND(max(CAST (b.NUM_CPU_CORES_PERC95 AS NUMERIC)), 0) as Server_Cores
        FROM (
                Select a.host_name,
                    a.hour,
                    sum(a.DB_CPU_CORES) as DB_CPU_CORES,
                    --sum the DB cores per instance on each host
                    max(a.NUM_CPU_CORES_PERC95) as NUM_CPU_CORES_PERC95
                From (
                        SELECT cpu.pkey,
                            cpu.dbid,
                            cpu.instance_number,
                            cpu.hour,
                            host.host_name,
                            DB_CPU_USAGE_PERCENTAGE,
                            HOST_CPU_USAGE_PERCENTAGE,
                            ROUND(
                                CAST (
                                    DB_CPU_USAGE_PERCENTAGE * (
                                        CASE
                                            WHEN (NUM_CPU_CORES_PERC95 = 0.0) THEN NUM_CPU_CORES_CALC_RVENG
                                            ELSE NUM_CPU_CORES_PERC95
                                        END
                                    ) / 100 AS NUMERIC
                                ),
                                2
                            ) DB_CPU_CORES,
                            --    ROUND(DB_CPU_USAGE_PERCENTAGE * (IF (NUM_CPU_CORES_PERC95 = 0.0, NUM_CPU_CORES_CALC_RVENG, NUM_CPU_CORES_PERC95))/100,2) DB_CPU_CORES,
                            CEIL(
                                CAST (
                                    HOST_CPU_USAGE_PERCENTAGE * (
                                        CASE
                                            WHEN (NUM_CPU_CORES_PERC95 = 0.0) THEN NUM_CPU_CORES_CALC_RVENG
                                            ELSE NUM_CPU_CORES_PERC95
                                        END
                                    ) AS NUMERIC
                                ) / 100
                            ) HOST_CORES,
                            NUM_CPU_CORES_PERC95,
                            NUM_CPUS_PERC95,
                            NUM_CPU_CORES_CALC_RVENG
                        FROM vhandlingzeroCPU cpu
                            inner join hostdetails host on host.PKEY = cpu.pkey
                            and host.instanceNumber = cpu.instance_number
                        order by 1,
                            2,
                            3,
                            4
                    ) a
                group by 1,
                    2
            ) b
        group by 1
    )
select *
from DBCPU;