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

IF OBJECT_ID('tempdb..#serverConfigurationParams') IS NOT NULL  
    DROP TABLE #serverConfigurationParams;

CREATE TABLE #serverConfigurationParams (
    configuration_id int, 
    name nvarchar(255),
    value nvarchar(255),
    minimum nvarchar(255),
    maximum nvarchar(255),
    value_in_use nvarchar(255),
    description nvarchar(255)
);

BEGIN
    exec ('
    INSERT INTO #serverConfigurationParams
    SELECT
	    configuration_id, 
        name,
        value,
        minimum,
        maximum,
        value_in_use, 
        description
    FROM sys.configurations');
END

SELECT 
    @PKEY as PKEY,
    configuration_id, 
    name,
    value,
    minimum,
    maximum,
    value_in_use, 
    description
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id
from #serverConfigurationParams;

IF OBJECT_ID('tempdb..#serverConfigurationParams') IS NOT NULL  
    DROP TABLE #serverConfigurationParams;