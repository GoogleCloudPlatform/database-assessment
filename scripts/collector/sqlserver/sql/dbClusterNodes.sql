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

IF OBJECT_ID('tempdb..#clusterNodesTable') IS NOT NULL  
    DROP TABLE #clusterNodesTable;

CREATE TABLE #clusterNodesTable (
    [NodeName] nvarchar(255), 
    [status] nvarchar(255), 
    [status_description] nvarchar(255)
);

IF @PRODUCT_VERSION >= 11
BEGIN TRY
    exec ('
    INSERT INTO #clusterNodesTable
    SELECT
	    NodeName AS node_name, 
        status, 
        status_description
    FROM sys.dm_os_cluster_nodes');
END TRY
BEGIN CATCH
	IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
		WAITFOR DELAY '00:00:00'
END CATCH

IF @PRODUCT_VERSION < 11
BEGIN TRY
    exec ('
    INSERT INTO #clusterNodesTable
    SELECT
	    NodeName, 
        NULL, 
        NULL
    FROM sys.dm_os_cluster_nodes');
END TRY
BEGIN CATCH
	IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
		WAITFOR DELAY '00:00:00'
    ELSE
    SELECT
        host_name() as host_name,
        db_name() as database_name,
        'columnDatatypes' as module_name,
        SUBSTRING(CONVERT(nvarchar,ERROR_NUMBER()),1,254) as error_number,
        SUBSTRING(CONVERT(nvarchar,ERROR_SEVERITY()),1,254) as error_severity,
        SUBSTRING(CONVERT(nvarchar,ERROR_STATE()),1,254) as error_state,
        SUBSTRING(CONVERT(nvarchar,ERROR_MESSAGE()),1,512) as error_message
END CATCH

SELECT 
    @PKEY as PKEY,
    NodeName AS node_name,
    status,
    status_description,
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id
from #clusterNodesTable;

IF OBJECT_ID('tempdb..#clusterNodesTable') IS NOT NULL  
    DROP TABLE #clusterNodesTable;