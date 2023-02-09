SELECT
COALESCE (PARSENAME (base_object_name, 3), DB_NAME (DB_ID ())) AS DB_name,
PARSENAME (base_object_name, 1) AS table_name,
 name AS synonym_name
FROM sys.synonyms