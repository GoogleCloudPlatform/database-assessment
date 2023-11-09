SELECT
  /*+ MAX_EXECUTION_TIME(5000) */
  table_schema,
  TABLE_NAME,
  ROUND(table_rows / 1000000, 2) Rows_Count,
  ROUND(data_length / (1024 * 1024 * 1024), 2) Data_Size,
  ROUND(index_length / (1024 * 1024 * 1024), 2) Index_Size,
  concat(char(39), @DMA_SOURCE_ID, char(39)) as DMA_SOURCE_ID,
  concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_MANUAL_ID
FROM information_schema.TABLES
WHERE table_schema NOT IN (
    'mysql',
    'information_schema',
    'performance_schema',
    'sys'
  )
  AND TABLE_TYPE <> 'VIEW'
ORDER BY data_length + index_length DESC
LIMIT 10;
