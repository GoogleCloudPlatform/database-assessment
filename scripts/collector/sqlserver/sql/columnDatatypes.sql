SET NOCOUNT ON
DECLARE @PKEY AS VARCHAR(256)
SELECT @PKEY = N'$(pkey)';
DECLARE @dbname VARCHAR(50)
DECLARE db_cursor CURSOR FOR 
SELECT name 
FROM MASTER.dbo.sysdatabases 
WHERE name NOT IN ('master','model','msdb','tempdb')

IF OBJECT_ID('tempdb..#columnDatatypes') IS NOT NULL  
   DROP TABLE #columnDatatypes;

CREATE TABLE #columnDatatypes(
    database_name nvarchar(255) DEFAULT db_name()
    ,schema_name nvarchar(255)
    ,table_name nvarchar(255)
    ,datatype nvarchar(255)
    ,max_length nvarchar(255)
    ,precision nvarchar(255)
    ,scale nvarchar(255)
    ,column_count nvarchar(255)
    );

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @dbname  

WHILE @@FETCH_STATUS = 0  
BEGIN
	exec ('
	use [' + @dbname + '];
	INSERT INTO #columnDatatypes (
      schema_name
      ,table_name
      ,datatype
      ,max_length
      ,precision
      ,scale
      ,column_count 
   )
   SELECT s.name AS schema_name
         , o.name AS table_name
         , t.name AS datatype
         , c.max_length
         , c.precision
         , c.scale
         , count(1) column_count
      FROM  sys.objects o 
      JOIN  sys.schemas s
         ON  s.schema_id = o.schema_id
      JOIN  sys.columns c
      ON  o.object_id = c.object_id
      JOIN  sys.types t
      ON  t.system_type_id = c.system_type_id AND t.user_type_id = c.user_type_id
   WHERE o.type_desc = ''USER_TABLE'' 
      AND t.system_type_id = t.user_type_id
   GROUP BY s.name
         , o.name
         , t.name
         , c.max_length
         , c.precision
         , c.scale
   ORDER BY s.name
         , o.name
         , t.name');
    FETCH NEXT FROM db_cursor INTO @dbname 
END 

CLOSE db_cursor  
DEALLOCATE db_cursor

SELECT @PKEY as PKEY, a.* from #columnDatatypes a;

DROP TABLE #columnDatatypes;