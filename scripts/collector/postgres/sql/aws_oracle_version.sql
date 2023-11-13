\ o output / opdb__awsoracleversion_ :VTAG.csv
SELECT chr(39) || :PKEY || chr(39),
       chr(39) || :DMA_SOURCE_ID || chr(39) AS DMA_SOURCE_ID,
       chr(39) || :DMA_MANUAL_ID || chr(39) AS DMA_MANUAL_ID,
       componentversion AS AWSExtensionVersion
FROM aws_oracle_ext.versions AS extVersion
