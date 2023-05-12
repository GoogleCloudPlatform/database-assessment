(SELECT USERNAME 
 FROM &v_tblprefix._users
 WHERE username IN ('ORDS_METADATA','ORDS_PUBLIC_USER','APEX_PUBLIC_USER', 'FLOWS_FILES', 'PERFSTAT', 'ORDSYS', 'MDSYS', 
                    'TSMSYS', 'WMSYS', 'CTXSYS', 'DMSYS', 'EXFSYS', 'OLAPSYS', 'XDB')
   OR username LIKE 'WWV_FLOWS%'
   OR username LIKE 'APEX%'
   OR username LIKE '%GGADMIN'
   OR username IN ( SELECT name FROM system.logstdby$skip_support where action=0)
)
