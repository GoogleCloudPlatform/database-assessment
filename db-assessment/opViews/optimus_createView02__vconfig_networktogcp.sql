SELECT TRIM(network_to_gcp)                  network_to_gcp,
       CAST(TRIM(gbytes_per_sec) AS NUMERIC) gbytes_per_sec,
       CAST(TRIM(mbytes_per_sec) AS NUMERIC) mbytes_per_sec
FROM   mydataset.optimusconfig_network_to_gcp;
