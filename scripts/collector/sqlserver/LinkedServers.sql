--Linked Servers
select product, count(product) as CountLinkedServers
from sys.servers
where is_linked = 1
GROUP BY product;