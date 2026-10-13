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

DECLARE @PKEY AS VARCHAR(256)
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

SELECT
    '"' + @PKEY + '"' AS PKEY,
    '"' + REPLACE(ISNULL(CONVERT(NVARCHAR(MAX), DB_NAME(vfs.database_id)), N''), '"', '""') + '"' AS DatabaseName,
    '"' + REPLACE(ISNULL(CONVERT(NVARCHAR(MAX), mf.name), N''), '"', '""') + '"' AS LogicalFileName,
    '"' + REPLACE(ISNULL(CONVERT(NVARCHAR(MAX), mf.type_desc), N''), '"', '""') + '"' AS FileType,
    '"' + REPLACE(ISNULL(CONVERT(NVARCHAR(MAX), mf.physical_name), N''), '"', '""') + '"' AS PhysicalPath,
    '"' + CONVERT(NVARCHAR(MAX), vfs.num_of_reads) + '"' AS TotalReads,
    '"' + CONVERT(NVARCHAR(MAX), vfs.num_of_bytes_read / 1024 / 1024) + '"' AS DataReadMB,
    '"' + CONVERT(NVARCHAR(MAX), vfs.io_stall_read_ms) + '"' AS TotalReadStallMs,
    '"' + CONVERT(NVARCHAR(MAX), CASE
        WHEN vfs.num_of_reads = 0 THEN 0
        ELSE vfs.io_stall_read_ms / vfs.num_of_reads
    END) + '"' AS AvgReadLatencyMs,
    '"' + CONVERT(NVARCHAR(MAX), vfs.num_of_writes) + '"' AS TotalWrites,
    '"' + CONVERT(NVARCHAR(MAX), vfs.num_of_bytes_written / 1024 / 1024) + '"' AS DataWrittenMB,
    '"' + CONVERT(NVARCHAR(MAX), vfs.io_stall_write_ms) + '"' AS TotalWriteStallMs,
    '"' + CONVERT(NVARCHAR(MAX), CASE
        WHEN vfs.num_of_writes = 0 THEN 0
        ELSE vfs.io_stall_write_ms / vfs.num_of_writes
    END) + '"' AS AvgWriteLatencyMs,
    '"' + CONVERT(NVARCHAR(MAX), vfs.io_stall) + '"' AS TotalIOStallMs,
    '"' + CONVERT(NVARCHAR(MAX), vfs.size_on_disk_bytes / 1024 / 1024) + '"' AS SizeOnDiskMB,
    '"' + @DMA_SOURCE_ID + '"' AS dma_source_id,
    '"' + @DMA_MANUAL_ID + '"' AS dma_manual_id
FROM
    sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
JOIN
    sys.master_files AS mf ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
ORDER BY
    vfs.io_stall DESC;
