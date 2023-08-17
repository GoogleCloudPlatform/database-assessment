\o output/opdb__awsoracleexists_:VTAG.csv
SELECT EXISTS
  (SELECT
   FROM information_schema.tables
   WHERE table_schema = 'aws_oracle_ext'
     AND TABLE_NAME = 'versions' ) AS SCTOracleExtensionExists
