SET NOCOUNT ON
SELECT
    N'$(pkey)' as PKEY,
	NodeName AS node_name, 
    status, 
    status_description
FROM sys.dm_os_cluster_nodes
;