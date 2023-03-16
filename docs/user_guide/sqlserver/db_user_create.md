# Database User Scripts (Optional)

The collection scripts can be executed with any DBA account. Alternately, a new user with the minimum privileges required for access with the following steps.  Two scripts are provided to create the user one that uses SQL Authentication and another that uses Windows Authentication.

## Create User

### Windows Authentication

```powershell
.\CreateUserForAssessmentWithWindowsAuth.bat
```

### SQL Authentication

```powershell
.\CreateUserForAssessmentWithSQLAuth.bat
```

### Grants
The user creation scripts will grant the appropriate permissions.  If the non default user is used, the sysadmin role must be granted:

```sql
EXEC master..sp_addsrvrolemember @loginame = N'[username]', @rolename = N'sysadmin'
```