-- init-mysql-script-base-path
select if(clean_version like '5.%', '5.7', 'base') as script_path
from (
    select if(
        version() rlike '^[0-9]+\.[0-9]+\.[0-9]+$' = 1,
        version(),
        SUBSTRING_INDEX(VERSION(), '.', 2) || '.0'
      ) as clean_version
  ) as base;
