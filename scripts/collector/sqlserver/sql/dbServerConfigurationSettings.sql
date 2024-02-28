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
set NOCOUNT on;

set LANGUAGE us_english;

declare @PKEY as VARCHAR(256)
declare @PRODUCT_VERSION as INTEGER
declare @DMA_SOURCE_ID as VARCHAR(256)
declare @DMA_MANUAL_ID as VARCHAR(256)
select @PKEY = N'$(pkey)';

select @PRODUCT_VERSION = convert(
        INTEGER,
        PARSENAME(
            convert(nvarchar, SERVERPROPERTY('productversion')),
            4
        )
    );

select @DMA_SOURCE_ID = N'$(dmaSourceId)';

select @DMA_MANUAL_ID = N'$(dmaManualId)';

if OBJECT_ID('tempdb..#serverConfigurationParams') is not null drop table #serverConfigurationParams;
create table #serverConfigurationParams
(
    configuration_id nvarchar(255),
    name nvarchar(255),
    value nvarchar(255),
    minimum nvarchar(255),
    maximum nvarchar(255),
    value_in_use nvarchar(255),
    description nvarchar(255)
);

begin exec (
    '
    INSERT INTO #serverConfigurationParams
    SELECT
        CONVERT(nvarchar(255),configuration_id), 
        CONVERT(nvarchar(255),name),
        CONVERT(nvarchar(255),value),
        CONVERT(nvarchar(255),minimum),
        CONVERT(nvarchar(255),maximum),
        CONVERT(nvarchar(255),value_in_use), 
        CONVERT(nvarchar(255),description)
    FROM sys.configurations'
);

end
select @PKEY as PKEY,
    configuration_id,
    name,
    value,
    minimum,
    maximum,
    value_in_use,
    description,
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id
from #serverConfigurationParams;
    if OBJECT_ID('tempdb..#serverConfigurationParams') is not null drop table #serverConfigurationParams;
