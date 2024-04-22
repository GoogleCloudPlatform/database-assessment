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

BEGIN
    exec ('
    SELECT
        ''"' + @PKEY + '"'' AS pkey,
        QUOTENAME(CONVERT(nvarchar(255),configuration_id),''"'') as configuration_id, 
        QUOTENAME(CONVERT(nvarchar(255),name),''"'') as name,
        QUOTENAME(CONVERT(nvarchar(255),value),''"'') as value,
        QUOTENAME(CONVERT(nvarchar(255),minimum),''"'') as minimum,
        QUOTENAME(CONVERT(nvarchar(255),maximum),''"'') as maximum,
        QUOTENAME(CONVERT(nvarchar(255),value_in_use),''"'') as value_in_use, 
        QUOTENAME(CONVERT(nvarchar(255),description),''"'') as description,
        ''"' + @DMA_SOURCE_ID + '"'' as dma_source_id,
        ''"' + @DMA_MANUAL_ID + '"'' as dma_manual_id
    FROM sys.configurations');
END
