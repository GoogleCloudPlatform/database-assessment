-- name: get-test
select *
from AWRHISTSYSMETRICHIST;


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