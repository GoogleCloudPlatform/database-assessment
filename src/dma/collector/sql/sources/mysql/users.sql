-- name: collection-mysql-users
select concat(char(34), @PKEY, char(34)) as pkey,
    concat(char(34), @DMA_SOURCE_ID, char(34)) as dma_source_id,
    concat(char(34), @DMA_MANUAL_ID, char(34)) as dma_manual_id,
    concat(char(34), user_host, char(34)) as user_host,
    user_count as user_count
from (
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
    ) src;
