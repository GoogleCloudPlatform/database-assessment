/*
Copyright 2024 Google LLC

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
DECLARE @PRODUCT_VERSION AS INTEGER;
DECLARE @CLOUDTYPE AS VARCHAR(256);

SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
SELECT @COLLECTION_USER = N'$(collectionUser)'
SELECT @CLOUDTYPE = 'NONE';

IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'

BEGIN
    IF @CLOUDTYPE = 'AZURE'
    BEGIN
        exec ('CREATE USER [' + @COLLECTION_USER + '] FROM LOGIN [' + @COLLECTION_USER + '] WITH DEFAULT_SCHEMA=dbo');
    END;
END;
