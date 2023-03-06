SET NOCOUNT ON
DECLARE @PKEY AS VARCHAR(256)
SELECT @PKEY = N'$(pkey)';
DECLARE @dbname VARCHAR(50)
DECLARE db_cursor CURSOR FOR 
SELECT name 
FROM MASTER.dbo.sysdatabases 
WHERE name NOT IN ('master','model','msdb','tempdb')

IF OBJECT_ID('tempdb..#objectList') IS NOT NULL  
   DROP TABLE #objectList;

CREATE TABLE #objectList(
    database_name nvarchar(255)
    ,object_type nvarchar(255)
    ,schema_name nvarchar(255)
    ,object_name nvarchar(255));

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @dbname  

WHILE @@FETCH_STATUS = 0  
BEGIN
	exec ('
	use [' + @dbname + '];
	INSERT INTO #objectList
    SELECT  DB_NAME() as database_name
    	   , o.type_desc AS object_type
           , s.name AS schema_name
           , o.name AS object_name
        FROM  sys.objects o 
        JOIN  sys.schemas s
          ON  s.schema_id = o.schema_id
       WHERE  o.type NOT IN (''S''  --SYSTEM_TABLE
                            ,''U''  --USER_TABLE
                            ,''ET'' --EXTERNAL_TABLE
                            ,''IT'' --INTERNAL_TABLE
                            )');
    FETCH NEXT FROM db_cursor INTO @dbname 
END 

CLOSE db_cursor  
DEALLOCATE db_cursor

SELECT @PKEY as PKEY, a.* from #objectList a ORDER BY object_type, schema_name, object_name;

DROP TABLE #objectList;