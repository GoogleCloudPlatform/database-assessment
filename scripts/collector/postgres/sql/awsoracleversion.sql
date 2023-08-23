\o output/opdb__awsoracleversion_:VTAG.csv
SELECT componentversion AS AWSExtensionVersion, 
       :DMA_SOURCE_ID
FROM aws_oracle_ext.versions AS extVersion
