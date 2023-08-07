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
DECLARE db_cursor CURSOR FOR 
SELECT name
FROM MASTER.sys.databases 
WHERE name NOT IN ('model','msdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
AND state = 0;

USE [master]
IF NOT EXISTS 
    (SELECT name  
     FROM master.sys.server_principals
     WHERE name = N'$(collectionUser)')
	BEGIN
		CREATE LOGIN [$(collectionUser)] WITH PASSWORD=N'$(collectionPass)', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
	END
BEGIN
	GRANT VIEW SERVER STATE TO [$(collectionUser)]
	GRANT SELECT ALL USER SECURABLES TO [$(collectionUser)]
	GRANT VIEW ANY DATABASE TO [$(collectionUser)]
	GRANT VIEW ANY DEFINITION TO [$(collectionUser)]
	GRANT VIEW SERVER STATE TO [$(collectionUser)]
END;

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @dbname  

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN
        exec ('
        use [' + @dbname + '];
        CREATE USER [$(collectionUser)] FOR LOGIN [$(collectionUser)];
        GRANT VIEW DATABASE STATE TO [$(collectionUser)]');
    END;

    FETCH NEXT FROM db_cursor INTO @dbname;
END;

CLOSE db_cursor  
DEALLOCATE db_cursor