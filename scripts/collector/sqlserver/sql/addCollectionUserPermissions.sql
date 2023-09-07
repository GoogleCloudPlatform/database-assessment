/*
Copyright 2023 Google LLC

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

SET NOCOUNT ON;
SET LANGUAGE us_english;

DECLARE @dbname VARCHAR(50);
DECLARE @COLLECTION_USER VARCHAR(256);
DECLARE @PRODUCT_VERSION AS INTEGER

SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
DECLARE db_cursor CURSOR FOR 
SELECT name
FROM MASTER.sys.databases 
WHERE name NOT IN ('model','msdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
AND state = 0;

BEGIN
	GRANT VIEW SERVER STATE TO [$(collectionUser)]
	GRANT SELECT ALL USER SECURABLES TO [$(collectionUser)]
	GRANT VIEW ANY DATABASE TO [$(collectionUser)]
	GRANT VIEW ANY DEFINITION TO [$(collectionUser)]
	GRANT VIEW SERVER STATE TO [$(collectionUser)]
    IF @PRODUCT_VERSION > 15
        BEGIN
            exec('GRANT VIEW SERVER PERFORMANCE STATE TO [$(collectionUser)]');
            exec('GRANT VIEW SERVER SECURITY STATE TO [$(collectionUser)]');
            exec('GRANT VIEW ANY PERFORMANCE DEFINITION TO [$(collectionUser)]');
            exec('GRANT VIEW ANY SECURITY DEFINITION TO [$(collectionUser)]');
        END;
END;

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @dbname  

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN
        exec ('
        use [' + @dbname + '];
        IF EXISTS (SELECT [name]
           FROM [sys].[database_principals]
           WHERE [type] = N''S'' AND [name] = N''$(collectionUser)'')
           BEGIN
             GRANT VIEW DATABASE STATE TO [$(collectionUser)];
           END');
    END;

    FETCH NEXT FROM db_cursor INTO @dbname;
END;

CLOSE db_cursor  
DEALLOCATE db_cursor