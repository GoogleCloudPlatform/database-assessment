with src as (
    SELECT u.host as user_host,
        count(1) AS user_count,
        sum(IF(u.authentication_string = '', 1, 0)) as user_no_authentication_string_count,
        sum(
            IF(
                u.host = '%'
                or u.host = '',
                1,
                0
            )
        ) as user_no_host_count,
        sum(
            IF(
                u.password = '',
                1,
                0
            )
        ) as user_no_password_count,
        sum(
            IF(
                u.shutdown_priv = 'Y'
                OR u.super_priv = 'Y'
                OR u.reload_priv = 'Y',
                1,
                0
            )
        ) as user_with_shutdown_privs_count
    FROM mysql.user u
    GROUP BY HOST
)
SELECT concat(char(39), @DMA_MANUAL_ID, char(39)) as PKEY,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as DMA_SOURCE_ID,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_MANUAL_ID,
    user_host,
    user_count
FROM src;
