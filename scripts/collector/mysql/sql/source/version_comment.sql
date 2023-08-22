tee output/opdb__version_comment__V_TAG
SELECT @@version_comment
                                , '_DMA_SOURCE_ID_' as DMA_SOURCE_ID
;
notee
