SELECT count(*) AS userCount,
       HOST,
       concat(char(39), @DMA_SOURCE_ID, char(39)) as DMA_SOURCE_ID,
       concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_MANUAL_ID
FROM mysql.user
WHERE (
              Shutdown_Priv = 'Y'
              OR Super_Priv = 'Y'
              OR Reload_Priv = 'Y'
       )
GROUP BY HOST;
