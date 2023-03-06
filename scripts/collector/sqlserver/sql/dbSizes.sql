SET NOCOUNT ON
SELECT
    N'$(pkey)' as PKEY, sizing.*
FROM(
SELECT
	DB_NAME(database_id) AS database_name, 
    type_desc, 
    SUM(size/128.0) AS current_size_mb
FROM sys.master_files
WHERE DB_NAME(database_id) NOT IN ('master', 'model', 'msdb')
AND type IN (0,1)
GROUP BY DB_NAME(database_id), type_desc) sizing
ORDER BY 2
;