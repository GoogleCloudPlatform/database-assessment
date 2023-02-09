--Collation name per column (not displaying column names)
SELECT distinct t.name TableName, collation_name  
FROM sys.columns c  
inner join sys.tables t on c.object_id = t.object_id
where collation_name IS NOT NULL;