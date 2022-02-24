var db_version varchar2(3)
var db_script varchar2(100)
column script new_val EXEC_SCRIPT
BEGIN
SELECT 
    CASE 
        WHEN banner LIKE '%12%' OR banner LIKE '%19.%' OR banner LIKE '%20.%' banner LIKE '%21%' 
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
