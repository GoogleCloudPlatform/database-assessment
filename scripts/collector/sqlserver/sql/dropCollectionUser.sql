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
set NOCOUNT on;

set LANGUAGE us_english;

declare @dbname VARCHAR(50);

declare @COLLECTION_USER VARCHAR(256);

declare db_cursor CURSOR for
select name
from sys.databases
where name not in (
        'model',
        'msdb',
        'distribution',
        'reportserver',
        'reportservertempdb',
        'resource',
        'rdsadmin'
    )
    and state = 0;

select @COLLECTION_USER = N'$(collectionUser)' open db_cursor fetch NEXT
from db_cursor into @dbname WHILE @@FETCH_STATUS = 0 begin begin exec (
        '
        use [' + @dbname + '];
        IF EXISTS (SELECT [name]
           FROM [sys].[database_principals]
           WHERE [type] = N''S'' AND [name] = N''' + @COLLECTION_USER + ''')
           BEGIN
             DROP USER [' + @COLLECTION_USER + '];
           END;
        '
    );

end;

fetch NEXT
from db_cursor into @dbname;

end;

CLOSE db_cursor DEALLOCATE db_cursor use [master];

if exists (
    select name
    from master.sys.server_principals
    where name = @COLLECTION_USER
) begin exec ('DROP LOGIN [' + @COLLECTION_USER + ']');

end;
