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
USE [master]
IF NOT EXISTS 
    (SELECT name  
     FROM master.sys.server_principals
     WHERE name = N'$(collectionUser)')
BEGIN
    CREATE LOGIN [$(collectionUser)] WITH PASSWORD=N'$(collectionPass)', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
END
GRANT VIEW SERVER STATE TO N'$(collectionUser)'
GO
GRANT SELECT ALL USER SECURABLES TO N'$(collectionUser)'
GO
GRANT VIEW ANY DATABASE TO N'$(collectionUser)'
GO
GRANT VIEW ANY DEFINITION TO N'$(collectionUser)'
GO
GRANT VIEW SERVER STATE TO N'$(collectionUser)'
GO