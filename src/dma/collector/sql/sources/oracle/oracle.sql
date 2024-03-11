-- name: collection-oracle-data-types
with data_types as (
    select
        /*+ USE_HASH(b a) NOPARALLEL */
        a.owner,
        data_type,
        count(1) as cnt,
        data_length,
        data_precision,
        data_scale,
        avg_col_len,
        count(distinct :CONN_ID || a.owner || table_name) as distinct_table_count
    from dba__tab_columns a
        inner join dba__objects b on & v_a_con_id = & v_b_con_id
        and a.owner = b.owner
        and a.table_name = b.object_name
        and b.object_type = 'TABLE'
    where a.owner not in (
            select USERNAME
            from & v_tblprefix._users
            where username in (
                    'ORDS_METADATA',
                    'ORDS_PUBLIC_USER',
                    'APEX_PUBLIC_USER',
                    'FLOWS_FILES',
                    'PERFSTAT',
                    'ORDSYS',
                    'MDSYS',
                    'TSMSYS',
                    'WMSYS',
                    'CTXSYS',
                    'DMSYS',
                    'EXFSYS',
                    'OLAPSYS',
                    'XDB',
                    'DBA_ADM',
                    'SYSTEM',
                    'CTXSYS',
                    'DBSNMP',
                    'EXFSYS',
                    'LBACSYS',
                    'MDSYS',
                    'MGMT_VIEW',
                    'OLAPSYS',
                    'ORDDATA',
                    'OWBSYS',
                    'ORDPLUGINS',
                    'ORDSYS',
                    'OUTLN',
                    'SI_INFORMTN_SCHEMA',
                    'SYS',
                    'SYSMAN',
                    'WK_TEST',
                    'WKSYS',
                    'WKPROXY',
                    'WMSYS',
                    'XDB',
                    'APEX_PUBLIC_USER',
                    'DIP',
                    'FLOWS_020100',
                    'FLOWS_030000',
                    'FLOWS_040100',
                    'FLOWS_010600',
                    'FLOWS_FILES',
                    'MDDATA',
                    'ORACLE_OCM',
                    'SPATIAL_CSW_ADMIN_USR',
                    'SPATIAL_WFS_ADMIN_USR',
                    'XS$NULL',
                    'PERFSTAT',
                    'SQLTXPLAIN',
                    'DMSYS',
                    'TSMSYS',
                    'WKSYS',
                    'APEX_040000',
                    'APEX_040200',
                    'DVSYS',
                    'OJVMSYS',
                    'GSMADMIN_INTERNAL',
                    'APPQOSSYS',
                    'DVSYS',
                    'DVF',
                    'AUDSYS',
                    'APEX_030200',
                    'MGMT_VIEW',
                    'ODM',
                    'ODM_MTR',
                    'TRACESRV',
                    'MTMSYS',
                    'OWBSYS_AUDIT',
                    'WEBSYS',
                    'WK_PROXY',
                    'OSE$HTTP$ADMIN',
                    'AURORA$JIS$UTILITY$',
                    'AURORA$ORB$UNAUTHENTICATED',
                    'DBMS_PRIVILEGE_CAPTURE',
                    'CSMIG',
                    'MGDSYS',
                    'SDE',
                    'DBSFWUSER'
                )
                or username like 'WWV_FLOWS%'
                or username like 'APEX%'
                or username like '%GGADMIN'
                or username in (
                    select name
                    from system.logstdby $skip_support
                    where action = 0
                )
        )
    group by a.owner,
        data_type,
        data_length,
        data_precision,
        data_scale,
        avg_col_len
)
select :PKEY as pkey,
    :CONN_ID as con_id,
    owner,
    data_type,
    cnt,
    data_length,
    data_precision,
    data_scale,
    avg_col_len,
    distinct_table_count,
    :DMA_SOURCE_ID as DMA_SOURCE_ID,
    :DMA_MANUAL_ID as DMA_MANUAL_ID
from data_types;
