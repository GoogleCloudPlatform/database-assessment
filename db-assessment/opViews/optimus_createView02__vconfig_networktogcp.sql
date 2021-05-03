select  trim(network_to_gcp) network_to_gcp,
        cast(trim(gbytes_per_sec) as numeric) gbytes_per_sec,
        cast(trim(mbytes_per_sec) as numeric) mbytes_per_sec
from `MYDATASET.optimusconfig_network_to_gcp`;
