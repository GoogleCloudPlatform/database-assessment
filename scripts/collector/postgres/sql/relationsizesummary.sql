\o output/opdb__relationsizesummary_:VTAG.csv
SELECT pg_total_relation_size(relid) AS total_size,
       pg_relation_size(relid) AS SIZE,
       *
FROM pg_stat_user_tables