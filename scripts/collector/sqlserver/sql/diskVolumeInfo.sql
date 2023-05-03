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

This script access Automatic Repository Workload (AWR) views in the database dictionary.
Please ensure you have proper licensing. For more information consult Oracle Support Doc ID 1490798.1

*/

SET NOCOUNT ON
DECLARE @PKEY AS VARCHAR(256)
SELECT @PKEY = N'$(pkey)';
SELECT DISTINCT
    @PKEY as PKEY,
    vs.volume_mount_point,
    vs.file_system_type,
    vs.logical_volume_name,
    CONVERT(DECIMAL(18, 2), vs.total_bytes / 1073741824.0) AS total_size_gb,
    CONVERT(DECIMAL(18, 2), vs.available_bytes / 1073741824.0) AS available_size_gb,
    CAST(CAST(vs.available_bytes AS float) / CAST(vs.total_bytes AS float) AS DECIMAL(18, 2)) * 100 AS space_free_pct
FROM
    sys.master_files AS f WITH (
        NOLOCK)
    CROSS APPLY sys.dm_os_volume_stats (f.database_id, f.[file_id]) AS vs OPTION (RECOMPILE);