# Database User Scripts (Optional)

The collection scripts can be executed with any DBA account. Alternately, a new user with the minimum privileges required for access with the following steps.

## Create User

### Non-container database

```sql
create user dmacollector identified by "Pa55w__rd123";
grant connect, create session to dmacollector;
```

### Container database

```sql
select * from v$system_parameter where name='common_user_prefix';
--C##
create user c##dmacollector identified by "Pa55w__rd123";
grant connect, create session to c##dmacollector;
```

## Grants

From the directory you extracted the collector scripts, change to the sql/setup directory:
```shell
cd sql/setup
```
Execute the grants_wrapper script
```sql
@grants_wrapper.sql
-- It will prompt for the user created above (Note that input is case-sensitive and must match the username created above).
-- You will also be prompted whether or not to allow access to the AWR data.
```


> AWR is a licensed feature of Oracle. If you don't have license to run AWR you can answer "N" to the above prompt and it will exclude the AWR data from collection.  If STATSPACK data is available, it will use that instead.
