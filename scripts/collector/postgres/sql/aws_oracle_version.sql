select chr(34) || :PKEY || chr(34),
    chr(34) || :DMA_SOURCE_ID || chr(34) as DMA_SOURCE_ID,
    chr(34) || :DMA_MANUAL_ID || chr(34) as DMA_MANUAL_ID,
    componentversion as aws_extension_version
from aws_oracle_ext.versions as e
