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
Date: 2022-02-01

*/

var db_version varchar2(3)
var db_script varchar2(100)
column script new_val EXEC_SCRIPT
BEGIN
SELECT 
    CASE 
        WHEN banner LIKE '%12%' OR banner LIKE '%19.%' OR banner LIKE '%20.%' OR banner LIKE '%21%' 
        THEN '19C' 
        ELSE 'OLD' 
    END ver
 INTO :db_version
 FROM v$version;
END;
/
print :db_version
BEGIN
 IF :db_version = '19C' then
 :db_script := 'oracle_db_assessment_12c_AND_ABOVE.sql';
 ELSE
 :db_script := 'oracle_db_assessment_ONLY_FOR_11g.sql';
 END IF;
END;
/
select :db_script script from dual;
@&EXEC_SCRIPT
