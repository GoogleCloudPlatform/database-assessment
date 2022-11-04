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
-- name: get-db-metrics
-- Get database metrics
select *
from T_DS_Database_Metrics;


-- name: get-cpu-calc
-- Get CPU Calculations
select *
from T_DS_CPU_CALC;


-- name: get-bms-sizing
-- Get CPU Calculations
select *
from T_DS_BMS_SIZING;


-- name: get-db-summary
-- Get DB Summary
select *
from V_DS_dbsummary;


-- name: get-db-features
-- Get DB Features
select *
from V_DS_dbfeatures;


-- name: get-host-details
-- Get Host Details
select *
from V_DS_HostDetails;


-- name: get-bms-bom
-- Get BMS Bill of Materials
select *
from T_DS_BMS_BOM;