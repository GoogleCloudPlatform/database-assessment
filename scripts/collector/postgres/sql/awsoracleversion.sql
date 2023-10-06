\o output/opdb__awsoracleversion_:VTAG.csv
SELECT componentversion AS AWSExtensionVersion, 
       chr(39) || :DMA_SOURCE_ID || chr(39) AS DMA_SOURCE_ID, chr(39) || :DMA_MANUAL_ID || chr(39) AS DMA_MANUAL_ID
FROM aws_oracle_ext.versions AS extVersion
