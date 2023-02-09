-- how many cores SQL Server can use (includes hyperthreading)
-- license determines how many cores can be used by SQL Server
select count(*) as cpu_count
from sys.dm_os_schedulers
where status = 'VISIBLE ONLINE' and is_online = 1;
