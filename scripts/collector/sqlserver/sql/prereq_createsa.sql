SET NOCOUNT ON
USE [master]
IF NOT EXISTS 
    (SELECT name  
     FROM master.sys.server_principals
     WHERE name = N'$(collectionUser)')
BEGIN
    CREATE LOGIN [$(collectionUser)] WITH PASSWORD=N'$(collectionPass)', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
END
EXEC master..sp_addsrvrolemember @loginame = N'$(collectionUser)', @rolename = N'sysadmin'