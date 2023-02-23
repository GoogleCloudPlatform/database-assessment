SET NOCOUNT ON
USE [master]
IF NOT EXISTS 
    (SELECT name  
     FROM master.sys.server_principals
     WHERE name = 'userfordma')
BEGIN
    CREATE LOGIN [userfordma] WITH PASSWORD=N'P@ssword135', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
END
EXEC master..sp_addsrvrolemember @loginame = N'userfordma', @rolename = N'sysadmin'