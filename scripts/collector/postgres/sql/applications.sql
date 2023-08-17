\o output/opdb__applications_:VTAG.csv
SELECT application_name,
       count(*)
FROM pg_stat_activity
GROUP BY 1
