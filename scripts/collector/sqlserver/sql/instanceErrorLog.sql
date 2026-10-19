/*
-- Author: Tim Chapman
Copyright 2026 Google LLC

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

DECLARE @PKEY AS VARCHAR(256);
DECLARE @DMA_SOURCE_ID AS VARCHAR(256);
DECLARE @DMA_MANUAL_ID AS VARCHAR(256);

SELECT @PKEY = N'$(pkey)';
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF OBJECT_ID('tempdb..#ErrLog') IS NOT NULL
    DROP TABLE #ErrLog;

CREATE TABLE #ErrLog (
    LogDate DATETIME,
    ProcessInfo VARCHAR(255),
    Text NVARCHAR(MAX)
);

BEGIN TRY
    INSERT INTO #ErrLog
    EXEC master.dbo.xp_readerrorlog 0, 1, NULL, NULL, NULL, NULL, N'desc';
END TRY
BEGIN CATCH
    -- Non-sysadmin / non-securityadmin logins without EXECUTE on xp_readerrorlog return an empty log set cleanly
END CATCH;

SELECT TOP 500
    '"' + @PKEY + '"' AS PKEY,
    '"' + CONVERT(VARCHAR(30), LogDate, 121) + '"' AS [timestamp],
    '"' + REPLACE(REPLACE(REPLACE(CONVERT(NVARCHAR(MAX), ISNULL(ProcessInfo, '')), '"', '""'), CHAR(13), ' '), CHAR(10), ' ') + '"' AS [process_info],
    '"' + LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(NVARCHAR(MAX), ISNULL(Text, N'')), '"', '""'), CHAR(13), ' '), CHAR(10), ' '))) + '"' AS [log_message],
    '"' + @DMA_SOURCE_ID + '"' AS dma_source_id,
    '"' + @DMA_MANUAL_ID + '"' AS dma_manual_id
FROM #ErrLog
WHERE Text NOT LIKE '%Login failed%'
  AND Text NOT LIKE '%password%'
  AND Text NOT LIKE '%SSPI handshake failed%'
ORDER BY LogDate DESC;

IF OBJECT_ID('tempdb..#ErrLog') IS NOT NULL
    DROP TABLE #ErrLog;
