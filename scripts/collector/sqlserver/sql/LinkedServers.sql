SET NOCOUNT ON;
USE [master]
--Linked Servers
select CAST(@@SERVERNAME + '_' + 'master' + '_' + @@ServiceName + '_' + FORMAT(GETDATE() , 'MMddyyHHmmss') AS VARCHAR(100)) AS PKEY, product, count(product) as CountOfLinkedServers
from sys.servers
where is_linked = 1
GROUP BY product;