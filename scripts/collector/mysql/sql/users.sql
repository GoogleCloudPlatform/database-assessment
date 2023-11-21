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
select concat(char(39), @DMA_MANUAL_ID, char(39)) as PKEY,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as DMA_SOURCE_ID,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_MANUAL_ID,
    user_host,
    user_count
from src;
