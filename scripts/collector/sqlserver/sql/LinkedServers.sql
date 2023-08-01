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
--Linked Servers
SET NOCOUNT ON;
SET LANGUAGE us_english;
DECLARE @PKEY AS VARCHAR(256)
DECLARE @CLOUDTYPE AS VARCHAR(256)
DECLARE @PRODUCT_VERSION AS INTEGER

SELECT @PKEY = N'$(pkey)';
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
SELECT @CLOUDTYPE = 'NONE'
IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'


IF OBJECT_ID('tempdb..#LinkedServersData') IS NOT NULL  
   DROP TABLE #LinkedServersData;  

CREATE TABLE #LinkedServersData
(
product NVARCHAR(255),
CountOfLinkedServers INT
)

IF @CLOUDTYPE = 'NONE'    
    INSERT INTO #LinkedServersData
    select product, 
        count(product) as CountOfLinkedServers
    from sys.servers
    where is_linked = 1
    GROUP BY product;

SELECT @PKEY as PKEY, a.* from #LinkedServersData a;

IF OBJECT_ID('tempdb..#LinkedServersData') IS NOT NULL  
   DROP TABLE #LinkedServersData;