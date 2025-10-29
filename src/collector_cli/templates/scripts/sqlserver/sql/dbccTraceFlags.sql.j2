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
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF OBJECT_ID('tempdb..#dbccTraceTable') IS NOT NULL
   DROP TABLE #dbccTraceTable;

CREATE TABLE #dbccTraceTable (
    [name] int,
    [status] int,
    [global] int,
    [session] int
);

INSERT INTO #dbccTraceTable exec('dbcc tracestatus()');

SELECT
    '"' + @PKEY + '"' as PKEY,
    '"' + CONVERT(NVARCHAR(255),a.name) + '"' as name,
    '"' + CONVERT(NVARCHAR(255),a.status) + '"' as status,
    '"' + CONVERT(NVARCHAR(255),a.global) + '"' as global,
    '"' + CONVERT(NVARCHAR(255),a.session) + '"' as session,
    '"' + @DMA_SOURCE_ID + '"' as dma_source_id,
    '"' + @DMA_MANUAL_ID + '"' as dma_manual_id
from #dbccTraceTable a;

IF OBJECT_ID('tempdb..#dbccTraceTable') IS NOT NULL
   DROP TABLE #dbccTraceTable;
