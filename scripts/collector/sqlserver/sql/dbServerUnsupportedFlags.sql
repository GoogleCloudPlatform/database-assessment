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

SELECT
    QUOTENAME(@PKEY,'"') as PKEY,
    QUOTENAME(CONVERT(NVARCHAR,lower(name)),'"') as flag_name,
    QUOTENAME(CONVERT(NVARCHAR,value),'"') as value,
    QUOTENAME(CONVERT(NVARCHAR,value_in_use),'"') as value_in_use,
    QUOTENAME(SUBSTRING(CONVERT(NVARCHAR,description), 1, 256),'"') AS description,
    QUOTENAME(@DMA_SOURCE_ID,'"') as dma_source_id,
    QUOTENAME(@DMA_MANUAL_ID,'"') as dma_manual_id
FROM
    sys.configurations
WHERE
    lower(name)
    /* The following configurations are supported per https://cloud.google.com/sql/docs/sqlserver/flags */
    NOT IN (
        'recovery interval (min)',
        'locks',
        'remote access',
        'default language',
        'remote login timeout (s)',
        'disallow results from triggers',
        'ft notify bandwidth (min)',
        'fill factor (%)',
        'max server memory (mb)',
        'query wait (s)',
        'default full-text language',
        'access check cache quota',
        'affinity mask',
        'external scripts enabled',
        'ft crawl bandwidth (min)',
        'default trace enabled',
        'access check cache bucket count',
        'two digit year cutoff',
        'max worker threads',
        'query governor cost limit',
        'nested triggers',
        'cross db ownership chaining',
        'optimize for ad hoc workloads',
        'automatic soft-numa disabled',
        'transform noise words',
        'contained database authentication',
        'ft notify bandwidth (max)',
        'cost threshold for parallelism',
        'max text repl size (b)',
        'index create memory (kb)',
        'remote query timeout (s)',
        'ft crawl bandwidth (max)',
        'agent xps',
        'cursor threshold',
        'user options',
        'user connections',
        'ph timeout (s)')
    AND value_in_use <> 0;
