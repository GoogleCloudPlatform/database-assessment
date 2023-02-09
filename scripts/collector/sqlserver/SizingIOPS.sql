--This script gives average IOPS, it wont record spikes in a particular hour. 
--If we want hourly IOPS we will need to fetch and store this data per hour or run perfmon
SET NOCOUNT ON
 
DECLARE @SQLRestartDateTime Datetime
DECLARE @TimeInSeconds Float
 
SELECT @SQLRestartDateTime = sqlserver_start_time from sys.dm_os_sys_info
 
SET @TimeInSeconds = Datediff(s,@SQLRestartDateTime,GetDate())
 
PRINT 'Input-Output Per Second and Bytes Per Second by Database and File'
PRINT ''
 
    SELECT   DB_NAME(IVFS.database_id) AS DatabaseName
           , MF.type_desc AS FileType
           , MF.name AS VirtualFileName
           , MF.Physical_Name AS StorageLocation
           , ROUND((num_of_reads + num_of_writes)/@TimeInSeconds,4) AS IOPS
           , ROUND((num_of_bytes_read + num_of_bytes_written)/@TimeInSeconds,2) AS BPS
      FROM sys.dm_io_virtual_file_stats(null,null) IVFS
      JOIN sys.master_files MF ON IVFS.database_id = MF.database_id AND IVFS.file_id = MF.file_id
  ORDER BY DatabaseName ASC, VirtualFileName ASC