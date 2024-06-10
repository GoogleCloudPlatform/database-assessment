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
SET nocount ON;
SET language us_english;
DECLARE @PKEY AS VARCHAR(256)
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @TABLE_PERMISSION_COUNT AS INTEGER
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

/* need to record table permissions in order to determine if we can run certain server level queryies
    as some tables are not available in managed instances
*/
IF Object_id('tempdb..#myPerms') IS NOT NULL
  DROP TABLE #myperms;
CREATE TABLE #myperms
  (
     entity_name     NVARCHAR(255),
     subentity_name  NVARCHAR(255),
     permission_name NVARCHAR(255)
  );
INSERT INTO #myperms
SELECT *
FROM   fn_my_permissions('sys.xp_regread', 'OBJECT')
WHERE  Upper(permission_name) = 'EXECUTE'
       AND subentity_name = '';
INSERT INTO #myperms
SELECT *
FROM   fn_my_permissions('sys.xp_servicecontrol', 'OBJECT')
WHERE  Upper(permission_name) = 'EXECUTE'
       AND subentity_name = '';
SELECT @TABLE_PERMISSION_COUNT = Count(*)
FROM   #myperms
WHERE  Lower(entity_name) IN ( 'sys.xp_regread', 'sys.xp_servicecontrol' )
       AND Upper(permission_name) = 'EXECUTE';

/* ------------------------------------------ Inital Setup -----------------------------------------------------*/
IF Object_id('tempdb..#RegResult') IS NOT NULL
  DROP TABLE #regresult;

IF Object_id('tempdb..#ServicesServiceStatus') IS NOT NULL
  DROP TABLE #servicesservicestatus;

IF Object_id('tempdb..#tempLanguageServices') IS NOT NULL
  DROP TABLE #tempLanguageServices;

CREATE TABLE #regresult
(
    resultvalue NVARCHAR(4)
)
CREATE TABLE #servicesservicestatus /*Create temp tables*/
(
    rowid             INT IDENTITY(1, 1),
    servername        NVARCHAR(128),
    servicename       NVARCHAR(128),
    servicestatus     VARCHAR(128),
    statusdatetime    DATETIME DEFAULT (Getdate()),
    physicalsrvername NVARCHAR(128)
)
CREATE TABLE #tempLanguageServices
(
    servicestatus NVARCHAR(256)
);

DECLARE @ChkInstanceName NVARCHAR(128) /*Stores SQL Instance Name*/
      ,
      @ChkSrvName      NVARCHAR(128) /*Stores Server Name*/
      ,
      @TrueSrvName     NVARCHAR(128) /*Stores where code name needed */
      ,
      @SQLSrv          NVARCHAR(128) /*Stores server name*/
      ,
      @PhysicalSrvName NVARCHAR(128) /*Stores physical name*/
      ,
      @FTS             NVARCHAR(128) /*Stores Full Text Search Service name*/
      ,
      @RS              NVARCHAR(128) /*Stores Reporting Service name*/
      ,
      @SQLAgent        NVARCHAR(128) /*Stores SQL Agent Service name*/
      ,
      @OLAP            NVARCHAR(128) /*Stores Analysis Service name*/
      ,
      @REGKEY          NVARCHAR(128) /*Stores Registry Key information*/
      ,
      @R_INFO_SERVICES NVARCHAR(256) /*Stores Info on R Language Installation information*/
  SET @PhysicalSrvName = Cast(Serverproperty('MachineName') AS VARCHAR(128))
  SET @ChkSrvName = Cast(Serverproperty('INSTANCENAME') AS VARCHAR(128))
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
      SET @TrueSrvName = Cast(Serverproperty('INSTANCENAME') AS VARCHAR(128))
      SET @SQLSrv = '$' + @ChkSrvName

      SELECT @OLAP = 'MSOLAP' + @SQLSrv /*Setting up proper service name*/

      SELECT @FTS = 'MSFTESQL' + @SQLSrv

      SELECT @RS = 'ReportServer' + @SQLSrv

      SELECT @SQLAgent = 'SQLAgent' + @SQLSrv

      SELECT @SQLSrv = 'MSSQL' + @SQLSrv
  END

/* ---------------------------------- SQL Server Service Section ----------------------------------------------*/
BEGIN TRY
SET @REGKEY = 'System\CurrentControlSet\Services\'
              + @SQLSrv
INSERT #regresult
       (resultvalue)
EXEC master.sys.Xp_regread
  @rootkey='HKEY_LOCAL_MACHINE',
  @key=@REGKEY
IF (SELECT resultvalue
    FROM   #regresult) = 1
   AND @TABLE_PERMISSION_COUNT >= 2
  BEGIN
      INSERT #servicesservicestatus
             (servicestatus) /*Detecting staus of SQL Sever service*/
      EXEC Xp_servicecontrol
        N'QUERYSTATE',
        @SQLSrv

      UPDATE #servicesservicestatus
      SET    servicename = 'MS SQL Server Service'
      WHERE  rowid = @@identity

      UPDATE #servicesservicestatus
      SET    servername = @TrueSrvName
      WHERE  rowid = @@identity

      UPDATE #servicesservicestatus
      SET    physicalsrvername = @PhysicalSrvName
      WHERE  rowid = @@identity

      TRUNCATE TABLE #regresult
  END
ELSE
  BEGIN
      INSERT INTO #servicesservicestatus
                  (servicestatus)
      VALUES      ('NOT INSTALLED')

      UPDATE #servicesservicestatus
      SET    servicename = 'MS SQL Server Service'
      WHERE  rowid = @@identity

      UPDATE #servicesservicestatus
      SET    servername = @TrueSrvName
      WHERE  rowid = @@identity

      UPDATE #servicesservicestatus
      SET    physicalsrvername = @PhysicalSrvName
      WHERE  rowid = @@identity

      TRUNCATE TABLE #regresult
  END
END TRY
BEGIN CATCH
  INSERT INTO #servicesservicestatus
              (servicestatus)
  VALUES      ('N/A')

  UPDATE #servicesservicestatus
  SET    servicename = 'MS SQL Server Service'
  WHERE  rowid = @@identity

  UPDATE #servicesservicestatus
  SET    servername = @TrueSrvName
  WHERE  rowid = @@identity

  UPDATE #servicesservicestatus
  SET    physicalsrvername = @PhysicalSrvName
  WHERE  rowid = @@identity

  TRUNCATE TABLE #regresult
END CATCH

/* ---------------------------------- SQL Server Agent Service Section -----------------------------------------*/
BEGIN TRY
SET @REGKEY = 'System\CurrentControlSet\Services\'
              + @SQLAgent
INSERT #regresult
       (resultvalue)
EXEC master.sys.Xp_regread
  @rootkey='HKEY_LOCAL_MACHINE',
  @key=@REGKEY
IF (SELECT resultvalue
    FROM   #regresult) = 1
   AND @TABLE_PERMISSION_COUNT >= 2
  BEGIN
      INSERT #servicesservicestatus
             (servicestatus) /*Detecting staus of SQL Agent service*/
      EXEC Xp_servicecontrol
        N'QUERYSTATE',
        @SQLAgent

      UPDATE #servicesservicestatus
      SET    servicename = 'SQL Server Agent Service'
      WHERE  rowid = @@identity

      UPDATE #servicesservicestatus
      SET    servername = @TrueSrvName
      WHERE  rowid = @@identity

      UPDATE #servicesservicestatus
      SET    physicalsrvername = @PhysicalSrvName
      WHERE  rowid = @@identity

      TRUNCATE TABLE #regresult
  END
ELSE
  BEGIN
      INSERT INTO #servicesservicestatus
                  (servicestatus)
      VALUES      ('NOT INSTALLED')

      UPDATE #servicesservicestatus
      SET    servicename = 'SQL Server Agent Service'
      WHERE  rowid = @@identity

      UPDATE #servicesservicestatus
      SET    servername = @TrueSrvName
      WHERE  rowid = @@identity

      UPDATE #servicesservicestatus
      SET    physicalsrvername = @PhysicalSrvName
      WHERE  rowid = @@identity

      TRUNCATE TABLE #regresult
  END
END TRY
BEGIN CATCH
  INSERT INTO #servicesservicestatus
              (servicestatus)
  VALUES      ('NOT INSTALLED')

  UPDATE #servicesservicestatus
  SET    servicename = 'SQL Server Agent Service'
  WHERE  rowid = @@identity

  UPDATE #servicesservicestatus
  SET    servername = @TrueSrvName
  WHERE  rowid = @@identity

  UPDATE #servicesservicestatus
  SET    physicalsrvername = @PhysicalSrvName
  WHERE  rowid = @@identity

  TRUNCATE TABLE #regresult
END CATCH

/* ---------------------------------- SQL Browser Service Section ----------------------------------------------*/
BEGIN TRY
  IF @TABLE_PERMISSION_COUNT >= 2
  BEGIN
    SET @REGKEY = 'System\CurrentControlSet\Services\SQLBrowser'

    INSERT #regresult
          (resultvalue)
    EXEC master.sys.Xp_regread
      @rootkey='HKEY_LOCAL_MACHINE',
      @key=@REGKEY
    IF (SELECT resultvalue
        FROM   #regresult) = 1
      BEGIN
          INSERT #servicesservicestatus
                (servicestatus) /*Detecting staus of SQL Browser Service*/
          EXEC master.dbo.Xp_servicecontrol
            N'QUERYSTATE',
            N'sqlbrowser'

          UPDATE #servicesservicestatus
          SET    servicename = 'SQL Browser Service - Instance Independent'
          WHERE  rowid = @@identity

          UPDATE #servicesservicestatus
          SET    servername = @TrueSrvName
          WHERE  rowid = @@identity

          UPDATE #servicesservicestatus
          SET    physicalsrvername = @PhysicalSrvName
          WHERE  rowid = @@identity

          TRUNCATE TABLE #regresult
      END
    IF (SELECT resultvalue
        FROM   #regresult) <> 1
      BEGIN
          INSERT INTO #servicesservicestatus
                      (servicestatus)
          VALUES      ('NOT INSTALLED')

          UPDATE #servicesservicestatus
          SET    servicename = 'SQL Browser Service - Instance Independent'
          WHERE  rowid = @@identity

          UPDATE #servicesservicestatus
          SET    servername = @TrueSrvName
          WHERE  rowid = @@identity

          UPDATE #servicesservicestatus
          SET    physicalsrvername = @PhysicalSrvName
          WHERE  rowid = @@identity

          TRUNCATE TABLE #regresult
      END
  END
  ELSE
  BEGIN
    INSERT INTO #servicesservicestatus
                (physicalsrvername,servername,servicename,servicestatus)
    VALUES      (@PhysicalSrvName,@TrueSrvName,'SQL Browser Service - Instance Independent','N/A')
  END
END TRY
BEGIN CATCH
  INSERT INTO #servicesservicestatus
              (physicalsrvername,servername,servicename,servicestatus)
  VALUES      (@PhysicalSrvName,@TrueSrvName,'SQL Browser Service - Instance Independent','N/A')
END CATCH

/* ---------------------------------- Integration Service Section ----------------------------------------------*/
BEGIN TRY
  IF @TABLE_PERMISSION_COUNT >= 2
  BEGIN
  SET @REGKEY = 'System\CurrentControlSet\Services\MsDtsServer'

  INSERT #regresult
        (resultvalue)
  EXEC master.sys.Xp_regread
    @rootkey='HKEY_LOCAL_MACHINE',
    @key=@REGKEY
    IF (SELECT resultvalue
      FROM   #regresult) = 1
    BEGIN
        INSERT #servicesservicestatus
              (servicestatus) /*Detecting staus of Intergration Service*/
        EXEC master.dbo.Xp_servicecontrol
          N'QUERYSTATE',
          N'sqlbrowser'

        UPDATE #servicesservicestatus
        SET    servicename = 'Integration Service - Instance Independent'
        WHERE  rowid = @@identity

        UPDATE #servicesservicestatus
        SET    servername = @TrueSrvName
        WHERE  rowid = @@identity

        UPDATE #servicesservicestatus
        SET    physicalsrvername = @PhysicalSrvName
        WHERE  rowid = @@identity

        TRUNCATE TABLE #regresult
    END
    IF (SELECT resultvalue
      FROM   #regresult) <> 1
    BEGIN
        INSERT INTO #servicesservicestatus
                    (servicestatus)
        VALUES      ('NOT INSTALLED')

        UPDATE #servicesservicestatus
        SET    servicename = 'Integration Service - Instance Independent'
        WHERE  rowid = @@identity

        UPDATE #servicesservicestatus
        SET    servername = @TrueSrvName
        WHERE  rowid = @@identity

        UPDATE #servicesservicestatus
        SET    physicalsrvername = @PhysicalSrvName
        WHERE  rowid = @@identity

        TRUNCATE TABLE #regresult
    END
  END
  ELSE
  BEGIN
    INSERT INTO #servicesservicestatus
                (physicalsrvername,servername,servicename,servicestatus)
    VALUES      (@PhysicalSrvName,@TrueSrvName,'Integration Service - Instance Independent','N/A')
  END
END TRY
BEGIN CATCH
  INSERT INTO #servicesservicestatus
              (physicalsrvername,servername,servicename,servicestatus)
  VALUES      (@PhysicalSrvName,@TrueSrvName,'Integration Service - Instance Independent','N/A')
END CATCH

/* ---------------------------------- Reporting Service Section ------------------------------------------------*/
BEGIN TRY
  IF @TABLE_PERMISSION_COUNT >= 2
  BEGIN
  SET @REGKEY = 'System\CurrentControlSet\Services\' + @RS

  INSERT #regresult
        (resultvalue)
  EXEC master.sys.Xp_regread
    @rootkey='HKEY_LOCAL_MACHINE',
    @key=@REGKEY
    IF (SELECT resultvalue
      FROM   #regresult) = 1
    BEGIN
        INSERT #servicesservicestatus
              (servicestatus) /*Detecting staus of Reporting service*/
        EXEC master.dbo.Xp_servicecontrol
          N'QUERYSTATE',
          N'sqlbrowser'

        UPDATE #servicesservicestatus
        SET    servicename = 'Reporting Service'
        WHERE  rowid = @@identity

        UPDATE #servicesservicestatus
        SET    servername = @TrueSrvName
        WHERE  rowid = @@identity

        UPDATE #servicesservicestatus
        SET    physicalsrvername = @PhysicalSrvName
        WHERE  rowid = @@identity

        TRUNCATE TABLE #regresult
    END
    IF (SELECT resultvalue
      FROM   #regresult) <> 1
    BEGIN
        INSERT INTO #servicesservicestatus
                    (servicestatus)
        VALUES      ('NOT INSTALLED')

        UPDATE #servicesservicestatus
        SET    servicename = 'Reporting Service'
        WHERE  rowid = @@identity

        UPDATE #servicesservicestatus
        SET    servername = @TrueSrvName
        WHERE  rowid = @@identity

        UPDATE #servicesservicestatus
        SET    physicalsrvername = @PhysicalSrvName
        WHERE  rowid = @@identity

        TRUNCATE TABLE #regresult
    END
  END
  ELSE
  BEGIN
    INSERT INTO #servicesservicestatus
                (physicalsrvername,servername,servicename,servicestatus)
    VALUES      (@PhysicalSrvName,@TrueSrvName,'Reporting Service','N/A')
  END
END TRY
BEGIN CATCH
  INSERT INTO #servicesservicestatus
              (physicalsrvername,servername,servicename,servicestatus)
  VALUES      (@PhysicalSrvName,@TrueSrvName,'Reporting Service','N/A')
END CATCH

/* ---------------------------------- Analysis Service Section -------------------------------------------------*/
BEGIN TRY
  IF @ChkSrvName IS NULL /*Detect default or named instance*/
    BEGIN
        SET @OLAP = 'MSSQLServerOLAPService'
    END
  ELSE
    BEGIN
        SET @OLAP = 'MSOLAP' + '$' + @ChkSrvName
        SET @REGKEY = 'System\CurrentControlSet\Services\'
                      + @OLAP
    END
  IF @TABLE_PERMISSION_COUNT >= 2
  BEGIN
  INSERT #regresult
        (resultvalue)
  EXEC master.sys.Xp_regread
    @rootkey='HKEY_LOCAL_MACHINE',
    @key=@REGKEY

  IF (SELECT resultvalue
      FROM   #regresult) = 1
    BEGIN
        INSERT #servicesservicestatus
              (servicestatus) /*Detecting staus of Analysis service*/
        EXEC master.dbo.Xp_servicecontrol
          N'QUERYSTATE',
          @OLAP

        UPDATE #servicesservicestatus
        SET    servicename = 'Analysis Services'
        WHERE  rowid = @@identity

        UPDATE #servicesservicestatus
        SET    servername = @TrueSrvName
        WHERE  rowid = @@identity

        UPDATE #servicesservicestatus
        SET    physicalsrvername = @PhysicalSrvName
        WHERE  rowid = @@identity

        TRUNCATE TABLE #regresult
    END
  IF (SELECT resultvalue
      FROM   #regresult) <> 1
    BEGIN
        INSERT INTO #servicesservicestatus
                    (servicestatus)
        VALUES      ('NOT INSTALLED')

        UPDATE #servicesservicestatus
        SET    servicename = 'Analysis Services'
        WHERE  rowid = @@identity

        UPDATE #servicesservicestatus
        SET    servername = @TrueSrvName
        WHERE  rowid = @@identity

        UPDATE #servicesservicestatus
        SET    physicalsrvername = @PhysicalSrvName
        WHERE  rowid = @@identity

        TRUNCATE TABLE #regresult
    END
  END
  ELSE
  BEGIN
    INSERT INTO #servicesservicestatus
                (physicalsrvername,servername,servicename,servicestatus)
    VALUES      (@PhysicalSrvName,@TrueSrvName,'Analysis Services','N/A')
  END
END TRY
BEGIN CATCH
  INSERT INTO #servicesservicestatus
              (physicalsrvername,servername,servicename,servicestatus)
  VALUES      (@PhysicalSrvName,@TrueSrvName,'Analysis Services','N/A')
END CATCH

/* ---------------------------------- Full Text Search Service Section -----------------------------------------*/
BEGIN TRY
  SET @REGKEY = 'System\CurrentControlSet\Services\' + @FTS

  IF @TABLE_PERMISSION_COUNT >= 2
  BEGIN
  INSERT #regresult
        (resultvalue)
  EXEC master.sys.Xp_regread
    @rootkey='HKEY_LOCAL_MACHINE',
    @key=@REGKEY

  IF (SELECT resultvalue
      FROM   #regresult) = 1
    BEGIN
        INSERT #servicesservicestatus
              (servicestatus) /*Detecting staus of Full Text Search service*/
        EXEC master.dbo.Xp_servicecontrol
          N'QUERYSTATE',
          @FTS

        UPDATE #servicesservicestatus
        SET    servicename = 'Full Text Search Service'
        WHERE  rowid = @@identity

        UPDATE #servicesservicestatus
        SET    servername = @TrueSrvName
        WHERE  rowid = @@identity

        UPDATE #servicesservicestatus
        SET    physicalsrvername = @PhysicalSrvName
        WHERE  rowid = @@identity

        TRUNCATE TABLE #regresult
    END
  IF (SELECT resultvalue
      FROM   #regresult) <> 1
    BEGIN
        INSERT INTO #servicesservicestatus
                    (servicestatus)
        VALUES      ('NOT INSTALLED')

        UPDATE #servicesservicestatus
        SET    servicename = 'Full Text Search Service'
        WHERE  rowid = @@identity

        UPDATE #servicesservicestatus
        SET    servername = @TrueSrvName
        WHERE  rowid = @@identity

        UPDATE #servicesservicestatus
        SET    physicalsrvername = @PhysicalSrvName
        WHERE  rowid = @@identity

        TRUNCATE TABLE #regresult
    END
  END
  ELSE
  BEGIN
    INSERT INTO #servicesservicestatus
                (physicalsrvername,servername,servicename,servicestatus)
    VALUES      (@PhysicalSrvName,@TrueSrvName,'Full Text Search Service','N/A')
  END
END TRY
BEGIN CATCH
  INSERT INTO #servicesservicestatus
              (physicalsrvername,servername,servicename,servicestatus)
  VALUES      (@PhysicalSrvName,@TrueSrvName,'Full Text Search Service','N/A')
END CATCH


/* ---------------------------------- Machine Learning and R Language Service Section -----------------------------------------*/
BEGIN TRY
	INSERT INTO #tempLanguageServices exec('sp_execute_external_script @language = N''R'', @script = N''OutputDataSet <- data.frame(.libPaths());''');
	SELECT @R_INFO_SERVICES = servicestatus from #tempLanguageServices;
	INSERT INTO #servicesservicestatus (physicalsrvername,servername,servicename,servicestatus)
		VALUES (@PhysicalSrvName,@TrueSrvName,'IsMachineLearningAndREnabled',CASE WHEN @R_INFO_SERVICES IS NOT NULL THEN 'INSTALLED' ELSE 'NOT INSTALLED' END)
END TRY
BEGIN CATCH
	IF ERROR_NUMBER() = 39020 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
		INSERT INTO #servicesservicestatus (physicalsrvername,servername,servicename,servicestatus)
		VALUES (@PhysicalSrvName,@TrueSrvName,'IsMachineLearningAndREnabled','NOT INSTALLED');
	IF ERROR_NUMBER() = 39020 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 2
		INSERT INTO #servicesservicestatus (physicalsrvername,servername,servicename,servicestatus)
		VALUES (@PhysicalSrvName,@TrueSrvName,'IsMachineLearningAndREnabled','NOT INSTALLED');
END CATCH;
/* -------------------------------------------------------------------------------------------------------------*/
SELECT '"' + @PKEY + '"'             AS PKEY,
       '"' + physicalsrvername + '"' AS 'physical_server_name',
       '"' + servername + '"'        AS 'sql_instance_name',
       '"' + servicename + '"'       AS 'sql_server_services',
       '"' + servicestatus + '"'     AS 'current_service_status',
       '"' + convert(varchar, statusdatetime, 121) + '"'    AS 'status_date_time',
       '"' + @DMA_SOURCE_ID + '"'    AS 'dma_source_id',
       '"' + @DMA_MANUAL_ID + '"'    AS 'dma_manual_id'
FROM   #servicesservicestatus

/* -------------------------------------------------------------------------------------------------------------*/
/*Perform cleanup*/
IF Object_id('tempdb..#RegResult') IS NOT NULL
  DROP TABLE #regresult
IF Object_id('tempdb..#ServicesServiceStatus') IS NOT NULL
  DROP TABLE #servicesservicestatus
IF Object_id('tempdb..#tempLanguageServices') IS NOT NULL
  DROP TABLE #tempLanguageServices
