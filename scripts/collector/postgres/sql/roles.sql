\ o output / opdb__roles_ :VTAG.csv
SELECT chr(39) || :PKEY || chr(39) as pkey,
  chr(39) || :DMA_SOURCE_ID || chr(39) AS dma_source_id,
  chr(39) || :DMA_MANUAL_ID || chr(39) AS dma_manual_id,
  r.oid::text AS roleName,
  r.rolsuper,
  r.rolinherit,
  r.rolcreaterole,
  r.rolcreatedb,
  r.rolcanlogin,
  r.rolconnlimit,
  r.rolvaliduntil,
  ARRAY (
    SELECT b.rolname
    FROM pg_catalog.pg_auth_members m
      JOIN pg_catalog.pg_roles b ON (m.roleid = b.oid)
    WHERE m.member = r.oid
  )::varchar(5000) AS memberof,
  pg_catalog.shobj_description(r.oid, 'pg_authid') AS description,
  r.rolreplication,
  r.rolbypassrls
FROM pg_catalog.pg_roles r
WHERE r.rolname !~ '^pg_'
ORDER BY 1
