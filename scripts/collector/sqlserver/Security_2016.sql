--Find Row level security policy
select count(*)
from sys.security_policies

--SQL Server 2016: to get all always encrypted columns
SELECT t.name AS TableName
    ,c.name AS ColumnName
    ,c.max_length
    ,k.name AS KeyName
    ,c.encryption_type_desc
    ,c.encryption_algorithm_name
FROM sys.columns c
INNER JOIN sys.column_encryption_keys k ON c.column_encryption_key_id = k.column_encryption_key_id
INNER JOIN sys.tables t ON c.object_id = t.object_id
WHERE encryption_type IS NOT NULL  

--find all maked columns in 2016
SELECT OBJECT_NAME(OBJECT_ID) TableName, 
Name ,
is_masked,
masking_function
FROM sys.masked_columns