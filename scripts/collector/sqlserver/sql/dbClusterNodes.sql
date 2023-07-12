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
SELECT @PKEY = N'$(pkey)';
DECLARE @PRODUCT_VERSION AS INTEGER
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));

IF OBJECT_ID('tempdb..#clusterNodesTable') IS NOT NULL  
    DROP TABLE #clusterNodesTable;

CREATE TABLE #clusterNodesTable (
    [NodeName] nvarchar(255), 
    [status] nvarchar(255), 
    [status_description] nvarchar(255)
);

IF @PRODUCT_VERSION >= 11
BEGIN
    exec ('
    use [master];
    INSERT INTO #clusterNodesTable
    SELECT
	    NodeName AS node_name, 
        status, 
        status_description
    FROM sys.dm_os_cluster_nodes');
END

IF @PRODUCT_VERSION < 11
BEGIN
    exec ('
    use [master];
    INSERT INTO #clusterNodesTable
    SELECT
	    NodeName, 
        NULL, 
        NULL
    FROM sys.dm_os_cluster_nodes');
END

SELECT @PKEY as PKEY,  NodeName AS node_name, status, status_description from #clusterNodesTable;

DROP TABLE #clusterNodesTable;