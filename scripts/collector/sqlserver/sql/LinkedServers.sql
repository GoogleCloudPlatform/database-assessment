SET NOCOUNT ON;
USE [master]
--Linked Servers
select product, count(product) as CountOfLinkedServers
from sys.servers
where is_linked = 1
GROUP BY product;