-- name: init-get-db-version$
select if(
    version() rlike '^[0-9]+\.[0-9]+\.[0-9]+$' = 1,
    version(),
    concat(SUBSTRING_INDEX(VERSION(), '.', 2), '.0')
  ) as db_version;

-- name: init-get-execution-id$
select concat(
    'mysql_',
    a.db_version,
    '_',
    DATE_FORMAT(SYSDATE(), '%Y%m%d%H%i%s')
  ) as execution_id
from (
    select if(
        version() rlike '^[0-9]+\.[0-9]+\.[0-9]+$' = 1,
        version(),
        concat(SUBSTRING_INDEX(VERSION(), '.', 2), '.0')
      ) as db_version
  ) a;

-- name: init-get-source-id$
select @@server_uuid as source_id;
