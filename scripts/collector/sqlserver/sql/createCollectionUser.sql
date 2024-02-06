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
DECLARE @COLLECTION_PASS VARCHAR(256);
DECLARE @PRODUCT_VERSION AS INTEGER

DECLARE db_cursor CURSOR FOR
SELECT name
FROM MASTER.sys.databases
WHERE name NOT IN ('model','msdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
AND state = 0;

SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
SELECT @COLLECTION_USER = N'$(collectionUser)'
SELECT @COLLECTION_PASS = N'$(collectionPass)'

IF NOT EXISTS
    (SELECT name
     FROM master.sys.server_principals
     WHERE name = @COLLECTION_USER)
	BEGIN
		exec ('CREATE LOGIN [' + @COLLECTION_USER + '] WITH PASSWORD=N''' + @COLLECTION_PASS + ''', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF');
	END
BEGIN
	exec ('GRANT VIEW SERVER STATE TO [' + @COLLECTION_USER + ']');
	exec ('GRANT VIEW ANY DATABASE TO [' + @COLLECTION_USER + ']');
	exec ('GRANT VIEW ANY DEFINITION TO [' + @COLLECTION_USER + ']');
	exec ('GRANT VIEW SERVER STATE TO [' + @COLLECTION_USER + ']');
    IF @PRODUCT_VERSION > 11
        BEGIN
        	exec ('GRANT SELECT ALL USER SECURABLES TO [' + @COLLECTION_USER + ']');
        END;
    IF @PRODUCT_VERSION > 15
        BEGIN
            exec('GRANT VIEW SERVER PERFORMANCE STATE TO [' + @COLLECTION_USER + ']');
            exec('GRANT VIEW SERVER SECURITY STATE TO [' + @COLLECTION_USER + ']');
            exec('GRANT VIEW ANY PERFORMANCE DEFINITION TO [' + @COLLECTION_USER + ']');
            exec('GRANT VIEW ANY SECURITY DEFINITION TO [' + @COLLECTION_USER + ']');
        END;
END;

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @dbname

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN
        exec ('
        use [' + @dbname + '];
        IF NOT EXISTS (SELECT [name]
           FROM [sys].[database_principals]
           WHERE [type] = N''S'' AND [name] = N''' + @COLLECTION_USER + ''')
           BEGIN
             CREATE USER [' + @COLLECTION_USER + '] FOR LOGIN  [' + @COLLECTION_USER + '];
           END;
        GRANT VIEW DATABASE STATE TO  [' + @COLLECTION_USER + ']');
    END;

    FETCH NEXT FROM db_cursor INTO @dbname;
END;

CLOSE db_cursor
DEALLOCATE db_cursor
