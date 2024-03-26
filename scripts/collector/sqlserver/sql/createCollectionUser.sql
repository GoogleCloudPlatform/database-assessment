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

declare @COLLECTION_PASS VARCHAR(256);

declare @PRODUCT_VERSION as INTEGER;

declare @CLOUDTYPE as VARCHAR(256);

declare db_cursor CURSOR for
select name
from sys.databases
where name not in (
        'model',
        'msdb',
        'tempdb',
        'distribution',
        'reportserver',
        'reportservertempdb',
        'resource',
        'rdsadmin'
    )
    and state = 0;

select @PRODUCT_VERSION = convert(
        INTEGER,
        PARSENAME(
            convert(nvarchar, SERVERPROPERTY('productversion')),
            4
        )
    );

select @COLLECTION_USER = N'$(collectionUser)'
select @COLLECTION_PASS = N'$(collectionPass)'
select @CLOUDTYPE = 'NONE';

if UPPER(@@VERSION) like '%AZURE%'
select @CLOUDTYPE = 'AZURE' if not exists (
        select name
        from master.sys.server_principals
        where name = @COLLECTION_USER
    ) begin if @CLOUDTYPE = 'AZURE' exec (
        'CREATE LOGIN [' + @COLLECTION_USER + '] WITH PASSWORD=N''' + @COLLECTION_PASS + ''''
    );

else exec (
    'CREATE LOGIN [' + @COLLECTION_USER + '] WITH PASSWORD=N''' + @COLLECTION_PASS + ''', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF'
);

end begin if @CLOUDTYPE = 'AZURE' begin exec (
    'ALTER SERVER ROLE ##MS_DefinitionReader## ADD MEMBER [' + @COLLECTION_USER + ']'
);

exec (
    'ALTER SERVER ROLE ##MS_SecurityDefinitionReader## ADD MEMBER [' + @COLLECTION_USER + ']'
);

exec (
    'ALTER SERVER ROLE ##MS_ServerStateReader## ADD MEMBER [' + @COLLECTION_USER + ']'
);

end;

if @CLOUDTYPE <> 'AZURE' begin exec (
    'GRANT VIEW SERVER STATE TO [' + @COLLECTION_USER + ']'
);

exec (
    'GRANT VIEW ANY DATABASE TO [' + @COLLECTION_USER + ']'
);

exec (
    'GRANT VIEW ANY DEFINITION TO [' + @COLLECTION_USER + ']'
);

if @PRODUCT_VERSION > 11 begin exec (
    'GRANT SELECT ALL USER SECURABLES TO [' + @COLLECTION_USER + ']'
);

end;

if (@PRODUCT_VERSION > 15) begin exec(
    'GRANT VIEW SERVER PERFORMANCE STATE TO [' + @COLLECTION_USER + ']'
);

exec(
    'GRANT VIEW SERVER SECURITY STATE TO [' + @COLLECTION_USER + ']'
);

exec(
    'GRANT VIEW ANY PERFORMANCE DEFINITION TO [' + @COLLECTION_USER + ']'
);

exec(
    'GRANT VIEW ANY SECURITY DEFINITION TO [' + @COLLECTION_USER + ']'
);

end;

end;

end;

if @CLOUDTYPE <> 'AZURE' begin open db_cursor fetch NEXT
from db_cursor into @dbname WHILE @@FETCH_STATUS = 0 begin exec (
        '
            use [' + @dbname + '];
            IF NOT EXISTS (SELECT [name]
            FROM [sys].[database_principals]
            WHERE [type] = N''S'' AND [name] = N''' + @COLLECTION_USER + ''')
            BEGIN
                CREATE USER [' + @COLLECTION_USER + '] FOR LOGIN  [' + @COLLECTION_USER + '];
            END;
            GRANT VIEW DATABASE STATE TO  [' + @COLLECTION_USER + ']
        '
    );

fetch NEXT
from db_cursor into @dbname;

end;

CLOSE db_cursor DEALLOCATE db_cursor
end;

if @CLOUDTYPE = 'AZURE' begin exec (
    'CREATE USER [' + @COLLECTION_USER + '] FROM LOGIN [' + @COLLECTION_USER + '] WITH DEFAULT_SCHEMA=dbo'
);

end;
