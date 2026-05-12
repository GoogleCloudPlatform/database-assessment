# Database User Scripts (Optional)

The collection scripts can be executed with any DBA account. Alternately, a new user with the minimum privileges required for access with the following steps. Two scripts are provided to create the user one that uses SQL Authentication and another that uses Windows Authentication.

---

## Create User

If an existing user with SYSADMIN privileges will not be used, from a command prompt, execute either of the following scripts depending on what type of authentication you currently use for your SYSADMIN user.

#### SQL Authentication

```powershell

.\createUserForAssessmentWithSQLAuth.bat

The following parameters can be specified:
    -serverName  ** Required
    -serverUserName  ** Required
    -serverUserPass  ** Optional at script level.  Will be prompted if not provided

        and

    -collectionUserName  ** Required if a custom username will be used
    -collectionUserPass  ** Optional at script level.  Will be prompted if not provided
```

#### Windows Authentication

```powershell
.\createUserForAssessmentWithWindowsAuth.bat

The following parameters can be specified:
    -serverName  ** Required
    -collectionUserName  ** Required if a custom username will be used
    -collectionUserPass  ** Optional at script level.  Will be prompted if not provided

```

---

## Grants

The supplied user creation scripts will automatically grant all appropriate permissions to the new database user during execution. 

If you choose to utilize an existing user instead, please see the dedicated [permissions.md](permissions.md) guide for the exact lists of data dictionary views and minimum server state permissions required across various SQL Server versions.

---

#### Notes
