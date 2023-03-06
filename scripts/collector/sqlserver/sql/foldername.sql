SET NOCOUNT ON;
SELECT CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(15)) AS Version, 
CAST(SERVERPROPERTY('MachineName') AS VARCHAR(15)) as machinename, 
'master'as databasename, 
@@ServiceName as instancename, 
FORMAT(GETDATE() , 'MMddyyHHmmss') as current_ts,
@@SERVERNAME + '_' + 'master' + '_' + @@ServiceName + '_' + FORMAT(GETDATE() , 'MMddyyHHmmss') as pkey;