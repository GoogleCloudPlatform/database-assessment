# Database User Scripts (Optional)

The collection scripts can be executed with any account with SYSADMIN privileges. Alternately, a new user with the minimum privileges required for access with the following steps. Two scripts are provided to create the user: one that uses SQL Authentication and another that uses Windows Authentication.

## Create User

If an existing user with SYSADMIN privileges will not be used, from a command prompt, execute either of the following scripts depending on what type of authentication you currently use for your SYSADMIN user.

### SQL Authentication

```powershell
.\createUserForAssessmentWithSQLAuth.bat -serverName [servername\instanceName] -port [port number] -serverUserName [existing privileged user] -serverUserPass [privileged user password] -collectionUserName [collection user name] -collectionUserPass [collection user password]
```

### Windows Authentication

```powershell
.\createUserForAssessmentWithWindowsAuth.bat -serverName [servername\instanceName] -port [port number] -collectionUserName [collection user name] -collectionUserPass [collection user password]
```

## Grants

The user creation scripts will grant the appropriate permissions. If it is desired to utilize an existing user, please see the [Permissions Required](permissions.md) page for the list of required grants.
