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
/* ------------------------------------------ Inital Setup -----------------------------------------------------*/
CREATE TABLE #RegResult
(
ResultValue NVARCHAR(4)
)
CREATE TABLE #ServicesServiceStatus /*Create temp tables*/
(
RowID INT IDENTITY(1,1)
,ServerName NVARCHAR(128)
,ServiceName NVARCHAR(128)
,ServiceStatus varchar(128)
,StatusDateTime DATETIME DEFAULT (GETDATE())
,PhysicalSrverName NVARCHAR(128)
)
DECLARE
@ChkInstanceName nvarchar(128) /*Stores SQL Instance Name*/
,@ChkSrvName nvarchar(128) /*Stores Server Name*/
,@TrueSrvName nvarchar(128) /*Stores where code name needed */
,@SQLSrv NVARCHAR(128) /*Stores server name*/
,@PhysicalSrvName NVARCHAR(128) /*Stores physical name*/
,@FTS nvarchar(128) /*Stores Full Text Search Service name*/
,@RS nvarchar(128) /*Stores Reporting Service name*/
,@SQLAgent NVARCHAR(128) /*Stores SQL Agent Service name*/
,@OLAP nvarchar(128) /*Stores Analysis Service name*/
,@REGKEY NVARCHAR(128) /*Stores Registry Key information*/
SET @PhysicalSrvName = CAST(SERVERPROPERTY('MachineName') AS VARCHAR(128))
SET @ChkSrvName = CAST(SERVERPROPERTY('INSTANCENAME') AS VARCHAR(128))
SET @ChkInstanceName = @@serverName
IF @ChkSrvName IS NULL /*Detect default or named instance*/
BEGIN
SET @TrueSrvName = 'MSQLSERVER'
SELECT @OLAP = 'MSSQLServerOLAPService' /*Setting up proper service name*/
SELECT @FTS = 'MSFTESQL'
SELECT @RS = 'ReportServer'
SELECT @SQLAgent = 'SQLSERVERAGENT'
SELECT @SQLSrv = 'MSSQLSERVER'
END
ELSE
BEGIN
SET @TrueSrvName = CAST(SERVERPROPERTY('INSTANCENAME') AS VARCHAR(128))
SET @SQLSrv = '$'+@ChkSrvName
SELECT @OLAP = 'MSOLAP' + @SQLSrv /*Setting up proper service name*/
SELECT @FTS = 'MSFTESQL' + @SQLSrv
SELECT @RS = 'ReportServer' + @SQLSrv
SELECT @SQLAgent = 'SQLAgent' + @SQLSrv
SELECT @SQLSrv = 'MSSQL' + @SQLSrv
END
/* ---------------------------------- SQL Server Service Section ----------------------------------------------*/
SET @REGKEY = 'System\CurrentControlSet\Services\'+@SQLSrv
INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY
IF (SELECT ResultValue FROM #RegResult) = 1
BEGIN
INSERT #ServicesServiceStatus (ServiceStatus) /*Detecting staus of SQL Sever service*/
EXEC xp_servicecontrol N'QUERYSTATE',@SQLSrv
UPDATE #ServicesServiceStatus set ServiceName = 'MS SQL Server Service' where RowID = @@identity
UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
TRUNCATE TABLE #RegResult
END
ELSE
BEGIN
INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')
UPDATE #ServicesServiceStatus set ServiceName = 'MS SQL Server Service' where RowID = @@identity
UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
TRUNCATE TABLE #RegResult
END
/* ---------------------------------- SQL Server Agent Service Section -----------------------------------------*/
SET @REGKEY = 'System\CurrentControlSet\Services\'+@SQLAgent
INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY
IF (SELECT ResultValue FROM #RegResult) = 1
BEGIN
INSERT #ServicesServiceStatus (ServiceStatus) /*Detecting staus of SQL Agent service*/
EXEC xp_servicecontrol N'QUERYSTATE',@SQLAgent
UPDATE #ServicesServiceStatus set ServiceName = 'SQL Server Agent Service' where RowID = @@identity
UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
TRUNCATE TABLE #RegResult
END
ELSE
BEGIN
INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')
UPDATE #ServicesServiceStatus set ServiceName = 'SQL Server Agent Service' where RowID = @@identity
UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
TRUNCATE TABLE #RegResult
END
/* ---------------------------------- SQL Browser Service Section ----------------------------------------------*/
SET @REGKEY = 'System\CurrentControlSet\Services\SQLBrowser'
INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY
IF (SELECT ResultValue FROM #RegResult) = 1
BEGIN
INSERT #ServicesServiceStatus (ServiceStatus) /*Detecting staus of SQL Browser Service*/
EXEC master.dbo.xp_servicecontrol N'QUERYSTATE',N'sqlbrowser'
UPDATE #ServicesServiceStatus set ServiceName = 'SQL Browser Service - Instance Independent' where RowID = @@identity
UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
TRUNCATE TABLE #RegResult
END
ELSE
BEGIN
INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')
UPDATE #ServicesServiceStatus set ServiceName = 'SQL Browser Service - Instance Independent' where RowID = @@identity
UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
TRUNCATE TABLE #RegResult
END
/* ---------------------------------- Integration Service Section ----------------------------------------------*/
SET @REGKEY = 'System\CurrentControlSet\Services\MsDtsServer'
INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY
IF (SELECT ResultValue FROM #RegResult) = 1
BEGIN
INSERT #ServicesServiceStatus (ServiceStatus) /*Detecting staus of Intergration Service*/
EXEC master.dbo.xp_servicecontrol N'QUERYSTATE',N'MsDtsServer'
UPDATE #ServicesServiceStatus set ServiceName = 'Intergration Service - Instance Independent' where RowID = @@identity
UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
TRUNCATE TABLE #RegResult
END
ELSE
BEGIN
INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')
UPDATE #ServicesServiceStatus set ServiceName = 'Intergration Service - Instance Independent' where RowID = @@identity
UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
TRUNCATE TABLE #RegResult
END
/* ---------------------------------- Reporting Service Section ------------------------------------------------*/
SET @REGKEY = 'System\CurrentControlSet\Services\'+@RS
INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY
IF (SELECT ResultValue FROM #RegResult) = 1
BEGIN
INSERT #ServicesServiceStatus (ServiceStatus) /*Detecting staus of Reporting service*/
EXEC master.dbo.xp_servicecontrol N'QUERYSTATE',@RS
UPDATE #ServicesServiceStatus set ServiceName = 'Reporting Service' where RowID = @@identity
UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
TRUNCATE TABLE #RegResult
END
ELSE
BEGIN
INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')
UPDATE #ServicesServiceStatus set ServiceName = 'Reporting Service' where RowID = @@identity
UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
TRUNCATE TABLE #RegResult
END
/* ---------------------------------- Analysis Service Section -------------------------------------------------*/
IF @ChkSrvName IS NULL /*Detect default or named instance*/
BEGIN
SET @OLAP = 'MSSQLServerOLAPService'
END
ELSE
BEGIN
SET @OLAP = 'MSOLAP'+'$'+@ChkSrvName
SET @REGKEY = 'System\CurrentControlSet\Services\'+@OLAP
END
INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY
IF (SELECT ResultValue FROM #RegResult) = 1
BEGIN
INSERT #ServicesServiceStatus (ServiceStatus) /*Detecting staus of Analysis service*/
EXEC master.dbo.xp_servicecontrol N'QUERYSTATE',@OLAP
UPDATE #ServicesServiceStatus set ServiceName = 'Analysis Services' where RowID = @@identity
UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
TRUNCATE TABLE #RegResult
END
ELSE
BEGIN
INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')
UPDATE #ServicesServiceStatus set ServiceName = 'Analysis Services' where RowID = @@identity
UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
TRUNCATE TABLE #RegResult
END
/* ---------------------------------- Full Text Search Service Section -----------------------------------------*/
SET @REGKEY = 'System\CurrentControlSet\Services\'+@FTS
INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY
IF (SELECT ResultValue FROM #RegResult) = 1
BEGIN
INSERT #ServicesServiceStatus (ServiceStatus) /*Detecting staus of Full Text Search service*/
EXEC master.dbo.xp_servicecontrol N'QUERYSTATE',@FTS
UPDATE #ServicesServiceStatus set ServiceName = 'Full Text Search Service' where RowID = @@identity
UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
TRUNCATE TABLE #RegResult
END
ELSE
BEGIN
INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')
UPDATE #ServicesServiceStatus set ServiceName = 'Full Text Search Service' where RowID = @@identity
UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
TRUNCATE TABLE #RegResult
END
/* -------------------------------------------------------------------------------------------------------------*/
SELECT 
/*CAST(@@SERVERNAME + '_' + 'master' + '_' + @@ServiceName + '_' + FORMAT(GETDATE() , 'MMddyyHHmmss') AS VARCHAR(256)) AS PKEY,*/
@PKEY as PKEY,
PhysicalSrverName AS 'Physical Server Name' /*Display finding*/
,ServerName AS 'SQL Instance Name'
,ServiceName AS 'SQL Server Services'
,ServiceStatus AS 'Current Service Service Status'
,StatusDateTime AS 'Date/Time Service Status Checked'
FROM #ServicesServiceStatus
/* -------------------------------------------------------------------------------------------------------------*/
DROP TABLE #ServicesServiceStatus /*Perform cleanup*/
DROP TABLE #RegResult