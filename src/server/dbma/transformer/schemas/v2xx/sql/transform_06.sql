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
--name: transform-06!
-- V_DS_dbsummary
CREATE OR REPLACE TABLE V_DS_dbsummary AS WITH awr AS (
        SELECT PKEY,
            MIN(
                strptime(
                    min_begin_interval_time,
                    '%d-%b-%y %I.%M.%S.%g %p'
                )
            ) AS begin_Date,
            MAX(
                strptime(
                    max_begin_interval_time,
                    '%d-%b-%y %I.%M.%S.%g %p'
                )
            ) AS End_date
        FROM awrsnapdetails
        GROUP BY PKEY
    ),
    a AS (
        SELECT DISTINCT dbsummary.pkey,
            dbsummary.dbid,
            db_name,
            cdb,
            db_version AS dbversion,
            db_fullversion AS dbfullversion,
            log_mode,
            force_logging,
            redo_gb_per_day,
            CAST(rac_dbinstaces AS numeric) AS rac_dbinstaces,
            characterset,
            platform_name,
            startup_time,
            user_schemas,
            CAST(buffer_cache_mb AS numeric) AS buffer_cache_mb,
            CAST(shared_pool_mb AS numeric) AS shared_pool_mb,
            CAST(total_pga_allocated_mb AS numeric) AS total_pga_allocated_mb,
            CAST(db_size_allocated_gb AS numeric) AS db_size_allocated_gb,
            CAST(db_size_in_use_gb AS numeric) AS db_size_in_use_gb,
            db_long_size_gb,
            dg_database_role,
            dg_protection_mode,
            dg_protection_level,
            awr.begin_date,
            awr.end_date,
            awr.end_date - awr.begin_date AS awr_collected_days,
            --IFNULL(SAFE_CAST(TRIM(SUBSTR(TRIM(awr.min_begin_interval_time),1,8)) as DATE  format 'DD-MON-YY'), SAFE_CAST(REPLACE(TRIM(SUBSTR(TRIM(awr.min_begin_interval_time),1,10)), '.', '-') as DATE  format 'DD-MM-YYYY')) Begin_date,
            --TO_DATE(SUBSTR(awr.min_begin_interval_time,1,9), 'DD-MON_RR') AS begin_Date,
            --IFNULL(SAFE_CAST(TRIM(SUBSTR(TRIM(awr.max_begin_interval_time),1,8)) as DATE  format 'DD-MON-YY'), SAFE_CAST(REPLACE(TRIM(SUBSTR(TRIM(awr.max_begin_interval_time),1,10)), '.', '-') as DATE  format 'DD-MM-YYYY')) End_date,
            --TO_DATE(SUBSTR(awr.max_begin_interval_time,1,9), 'DD-MON_RR') AS End_date,
            /*
             DATE_DIFF(IFNULL(SAFE_CAST(TRIM(SUBSTR(TRIM(awr.max_begin_interval_time),1,8)) as DATE  format 'DD-MON-YY'), SAFE_CAST(REPLACE(TRIM(SUBSTR(TRIM(awr.max_begin_interval_time),1,10)), '.', '-') as DATE  format 'DD-MM-YYYY')),
             IFNULL(SAFE_CAST(TRIM(SUBSTR(TRIM(awr.min_begin_interval_time),1,8)) as DATE  format 'DD-MON-YY'), SAFE_CAST(REPLACE(TRIM(SUBSTR(TRIM(awr.min_begin_interval_time),1,10)), '.', '-') as DATE  format 'DD-MM-YYYY')), DAY) as AWR_collected_days,
             */
            --TO_DATE(SUBSTR(awr.max_begin_interval_time,1,9), 'DD-MON_RR') - TO_DATE(SUBSTR(awr.min_begin_interval_time,1,9), 'DD-MON_RR') as AWR_collected_days,
            features.name AS DB_feature_name,
            features.current_usage AS DB_feature_usage --,
            --awr.hour
        FROM dbsummary --inner join awrsnapdetails as awr using (PKEY)
            INNER JOIN awr USING (PKEY)
            INNER JOIN dbfeatures AS features USING (PKEY) --ON dbsummary.PKEY = awr.PKEY
        WHERE --awr.hour=14
            --and 
            features.name LIKE '%Exadata%'
    )
SELECT a.*,
    CASE
        WHEN a.DB_feature_usage = 'False' THEN 'Non-Exadata'
        WHEN a.DB_feature_usage = 'True' THEN 'Exadata'
        ELSE 'UNKOWN'
    END AS Is_Exadata
FROM a;