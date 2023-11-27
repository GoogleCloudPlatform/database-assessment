with src as (
    select u.host as user_host,
        count(1) as user_count,
        sum(if(u.authentication_string = '', 1, 0)) as user_no_authentication_string_count,
        sum(
            if(
                u.host = '%'
                or u.host = '',
                1,
                0
            )
        ) as user_no_host_count,
        sum(
            if(
                u.authentication_string = '',
                1,
                0
            )
        ) as user_no_password_count,
        sum(
            if(
                u.shutdown_priv = 'Y'
                or u.super_priv = 'Y'
                or u.reload_priv = 'Y',
                1,
                0
            )
        ) as user_with_shutdown_privs_count
    from mysql.user u
    group by HOST
)
select concat(char(39), @PKEY, char(39)) as pkey,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as dma_source_id,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as dma_manual_id,
    concat(char(39), user_host, char(39)) as user_host,
    concat(char(39), user_count, char(39)) as user_count
from src;
