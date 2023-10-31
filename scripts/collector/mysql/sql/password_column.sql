SELECT CASE WHEN column_name = 'authentication_string' THEN 'password' 
            ELSE 'authentication_string' 
	   END
FROM information_schema.columns
WHERE column_name IN ('authentication_string', 'password')
  AND table_name = 'user';
