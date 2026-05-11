# Permissions Required

The collection scripts can be executed with any account with SYSADMIN privileges. Alternatively, create a new user with the minimum privileges required.

The included scripts `createUserForAssessmentWithSQLAuth.bat` and `createUserForAssessmentWithWindowsAuth.bat` will grant the privileges listed below.
Please see the Database User Scripts page for information on how to create the user.

## Permissions Required

The following permissions are required for the script execution:

### In the master database:
- `GRANT VIEW SERVER STATE TO [username];`
- `GRANT SELECT ALL USER SECURABLES TO [username];`
- `GRANT VIEW ANY DATABASE TO [username];`
- `GRANT VIEW ANY DEFINITION TO [username];`
- `GRANT VIEW SERVER STATE TO [username];`

### For SQL Server Version 2022 and above the following additional permissions are needed:
- `GRANT VIEW SERVER PERFORMANCE STATE TO [username];`
- `GRANT VIEW SERVER SECURITY STATE TO [username];`
- `GRANT VIEW ANY PERFORMANCE DEFINITION TO [username];`
- `GRANT VIEW ANY SECURITY DEFINITION TO [username];`

### For Azure SQL Database the following permissions are also granted:
- `ALTER SERVER ROLE ##MS_DefinitionReader## ADD MEMBER [username];`
- `ALTER SERVER ROLE ##MS_SecurityDefinitionReader## ADD MEMBER [username];`
- `ALTER SERVER ROLE ##MS_ServerStateReader## ADD MEMBER [username];`

### In each user database:
- `CREATE USER [username] FOR LOGIN [username];`
- `GRANT VIEW DATABASE STATE TO [username];`
