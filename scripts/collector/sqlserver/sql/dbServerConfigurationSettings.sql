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

DECLARE @PKEY AS VARCHAR(256)
DECLARE @PRODUCT_VERSION AS INTEGER
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

BEGIN
    exec ('
    SELECT
        ''' + @PKEY + ''' AS pkey,
        CONVERT(nvarchar(255),configuration_id) as configuration_id, 
        CONVERT(nvarchar(255),name) as name,
        CONVERT(nvarchar(255),value) as value,
        CONVERT(nvarchar(255),minimum) as minimum,
        CONVERT(nvarchar(255),maximum) as maximum,
        CONVERT(nvarchar(255),value_in_use) as value_in_use, 
        CONVERT(nvarchar(255),description) as description,
        ''' + @DMA_SOURCE_ID + ''' as dma_source_id,
        ''' + @DMA_MANUAL_ID + ''' as dma_manual_id
    FROM sys.configurations');
END