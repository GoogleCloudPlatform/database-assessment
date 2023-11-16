select chr(39) || :PKEY || chr(39),
    chr(39) || :DMA_SOURCE_ID || chr(39) as DMA_SOURCE_ID,
    chr(39) || :DMA_MANUAL_ID || chr(39) as DMA_MANUAL_ID,
    componentversion as aws_extension_version
from aws_oracle_ext.versions as extVersion
