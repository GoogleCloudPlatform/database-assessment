tee output/opdb__compressedtables__V_TAG
SELECT /*+ MAX_EXECUTION_TIME(5000) */ CONCAT(table_schema, '.', TABLE_NAME) Schema_Table,
                                       ROUND(table_rows / 1000000, 2) Rows_Count,
                                       ROUND(data_length / (1024 * 1024 * 1024), 2) Data_Size,
                                       ROUND(index_length / (1024 * 1024 * 1024), 2) Index_Size
				, '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
FROM information_schema.TABLES
WHERE table_schema NOT IN ('mysql',
                           'information_schema',
                           'performance_schema',
                           'sys')
  AND ROW_FORMAT='COMPRESSED'
ORDER BY data_length + index_length DESC
;
notee
