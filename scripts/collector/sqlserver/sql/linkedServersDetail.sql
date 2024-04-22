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
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @CLOUDTYPE = 'NONE'
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'

BEGIN
    BEGIN TRY
    exec('   
        select
            ''"' + @PKEY + '"'' AS pkey,
            QUOTENAME(name,''"'') as name, 
            QUOTENAME(product,''"'') as product,
            QUOTENAME(provider,''"'') as provider,
            QUOTENAME(data_source,''"'') as data_source,
            QUOTENAME(location,''"'') as location,
            QUOTENAME(provider_string,''"'') as provider_string,
            QUOTENAME(catalog,''"'') as catalog,
            ''"' + @DMA_SOURCE_ID + '"'' as dma_source_id,
            ''"' + @DMA_MANUAL_ID + '"'' as dma_manual_id
        from sys.servers
        where is_linked = 1
            and server_id <> 0');
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
            WAITFOR DELAY '00:00:00'
    END CATCH
END;
