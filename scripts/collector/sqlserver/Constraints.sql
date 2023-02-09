SELECT 
OBJECT_NAME(parent_object_id) AS TableName,
type_desc AS ConstraintType,
count(type_desc) as count_constraint
FROM sys.objects
WHERE type_desc LIKE '%CONSTRAINT'
group by OBJECT_NAME(parent_object_id),type_desc
order by TableName;