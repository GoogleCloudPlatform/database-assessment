# Database User Scripts (Optional)

The collection scripts can be executed with any DBA account. Alternately, a new user with the minimum privileges required for access with the following steps.

## Create User

### PDB (Recommended)

```sql
create user optimusprime identified by "Pa55w__rd123";
```

### CDB

```sql
select * from v$system_parameter where name='common_user_prefix';
--C##
create user C##optimusprime identified by "Pa55w__rd123";
```

## Grants

From the directory you extracted the collector scripts:

```sql
@sql/grants_wrapper.sql
-- It will prompt for the user created above
```

> NOTE: grants_wrapper.sql has provided variable db_awr_license which is set default to Y to access AWR tables.
>
> AWR is a licensed feature of Oracle. If you don't have license to run AWR you can disable flag and it will execute script minimum_select_grants_for_targets_ONLY_FOR_11g.sql.
