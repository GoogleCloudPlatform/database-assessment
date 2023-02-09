--Outputs number of views in a database
SELECT count(TABLE_NAME) as ViewCnt
FROM INFORMATION_SCHEMA.VIEWS;

