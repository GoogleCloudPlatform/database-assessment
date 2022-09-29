/*
Copyright 2021 Google LLC

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

/*

Version: 2.0.3
Date: 2022-03-10

*/

set verify off

accept dbusername char prompt "Please enter the DB Local Username(Or CDB Username) to receive all required grants: "


/*
        Use db_awr_license variable to OVERRIDE license usage.
        i.e. db_awr_license='Y' when you want to use AWR views irrespective of if you have license to run AWR or not
        Keep db_awr_license='N' if you don't want to query any AWR tables.
*/


def db_awr_license='Y'

var db_version varchar2(3)
var v_awr_license varchar2(3)
var db_script varchar2(100)
column script new_val EXEC_SCRIPT

/* Find Current Database Version */
BEGIN
SELECT
    CASE
        WHEN banner LIKE '%12%' OR banner LIKE '%19.%' OR banner LIKE '%20.%' OR banner LIKE '%21%'
        THEN '19C'
        ELSE 'OLD'
    END ver
 INTO :db_version
 FROM v$version
 WHERE ROWNUM=1;
END;
/
print :db_version

/* Find AWR Licensed Usage */
BEGIN
SELECT
    CASE
        WHEN (value LIKE 'DIAG' OR value LIKE 'TUNING' ) OR '&db_awr_license'='Y'
        THEN '19C'
        ELSE 'OLD'
    END ver
 INTO :v_awr_license
 FROM v$parameter
WHERE UPPER(name) = 'CONTROL_MANAGEMENT_PACK_ACCESS';
END;
/

print :v_awr_license
BEGIN
 IF :db_version = '19C' and :v_awr_license = '19C' then
        :db_script := 'minimum_select_grants_for_targets_12c_AND_ABOVE.sql';
 ELSE
        :db_script := 'minimum_select_grants_for_targets_ONLY_FOR_11g.sql';
 END IF;
END;
/
select :db_script script from dual;
@&EXEC_SCRIPT
exit;
