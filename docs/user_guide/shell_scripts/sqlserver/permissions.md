# Create a user for Collection

 The collection scripts can be executed with any SYSADMIN account. Alternatively, create a new user with the minimum privileges required.
 The included scripts createUserForAssessmentWithSQLAuth.bat and createUserForAssessmentWithWindowsAuth.bat will grant the privileges listed below.
 Please see the Database User Scripts page for information on how to create the user.

## Permissions Required

This utility must be run as a database user with privileges to SELECT from certain data dictionary views. If it is desired to utilize an existing user, the following grants must be granted. From the master database:

```sql
  GRANT VIEW SERVER STATE TO [username];
  GRANT SELECT ALL USER SECURABLES TO [username];
  GRANT VIEW ANY DATABASE TO [username];
  GRANT VIEW ANY DEFINITION TO [username];
  GRANT VIEW SERVER STATE TO [username];
  GRANT VIEW DATABASE STATE TO [username];
```

For SQL Server Versions 2022 and above, the following additional permissions will be granted:

```sql
  GRANT VIEW SERVER PERFORMANCE STATE TO [username];
  GRANT VIEW SERVER SECURITY STATE TO [username];
  GRANT VIEW ANY PERFORMANCE DEFINITION TO [username];
  GRANT VIEW ANY SECURITY DEFINITION TO [username];
```

For Azure SQL Database, the following grants are executed:

```sql
  ALTER SERVER ROLE ##MS_DefinitionReader## ADD MEMBER [username];
  ALTER SERVER ROLE ##MS_SecurityDefinitionReader## ADD MEMBER [username];
  ALTER SERVER ROLE ##MS_ServerStateReader## ADD MEMBER [username];
```

In addition the user must also be mapped to all user databases, tempdb and master databases along with the following grant:

```sql
  use [user database name];
  CREATE USER [username] FOR LOGIN [username];
  GRANT VIEW DATABASE STATE TO [username];
```
