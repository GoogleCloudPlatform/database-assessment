\o output/opdb__databasesize_:VTAG.csv
SELECT round(pg_database_size(datname)/(1024.0 * 1024 * 1024), 2) AS SIZE,
       *
FROM pg_stat_database
