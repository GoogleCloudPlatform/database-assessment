\o output/opdb__sproccount_:VTAG.csv
SELECT proowner::varchar(255),
       l.lanname,
       count(*)
FROM pg_proc pr
JOIN pg_language l ON l.oid = pr.prolang
GROUP BY 1,
         2
