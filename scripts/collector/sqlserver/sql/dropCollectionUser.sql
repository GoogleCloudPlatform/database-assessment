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
FROM sys.databases
WHERE name NOT IN ('model','msdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
    AND state = 0
    AND is_read_only = 0;

SELECT @COLLECTION_USER = N'$(collectionUser)'

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @dbname

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN
        exec ('
        use [' + @dbname + '];
        IF EXISTS (SELECT [name]
           FROM [sys].[database_principals]
           WHERE [type] = N''S'' AND [name] = N''' + @COLLECTION_USER + ''')
           BEGIN
             DROP USER [' + @COLLECTION_USER + '];
           END;
        ');
    END;

    FETCH NEXT FROM db_cursor INTO @dbname;
END;

CLOSE db_cursor
DEALLOCATE db_cursor

use [master];
IF EXISTS
    (SELECT name
FROM master.sys.server_principals
WHERE name = @COLLECTION_USER)
	BEGIN
    exec ('DROP LOGIN [' + @COLLECTION_USER + ']');
END;
