SET NOCOUNT ON
USE [master]
IF NOT EXISTS 
    (SELECT name  
     FROM master.sys.server_principals
     WHERE name = '$(collectionUserName)')
BEGIN
    CREATE LOGIN [$(collectionUserName)] WITH PASSWORD=N'$(CollectionUserPass)', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
END
EXEC master..sp_addsrvrolemember @loginame = N'$(collectionUserName)', @rolename = N'sysadmin'