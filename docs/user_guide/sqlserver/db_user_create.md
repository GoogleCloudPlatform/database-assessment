# Database User Scripts (Optional)

The collection scripts can be executed with any DBA account. Alternately, a new user with the minimum privileges required for access with the following steps. Two scripts are provided to create the user one that uses SQL Authentication and another that uses Windows Authentication.

---

## Create User

If an existing user with SYSADMIN privileges wil not be used, from a command prompt, execute either of the following scripts depending on what type of authentication you currently use for your SYSADMIN user.

#### SQL Authentication

```powershell

.\CreateUserForAssessmentWithSQLAuth.bat

The following parameters can be specified:
    -serverName  ** Required
    -serverUserName  ** Required
    -serverUserPass  ** Required

        and

    -collectionUserName  ** Required if a custom username will be used
    -collectionUserPass  ** Required if a custom password will be used

        or

    -useDefaultCreds  ** Required if custom credentials are not desired
```

#### Windows Authentication

```powershell
.\CreateUserForAssessmentWithWindowsAuth.bat

The following parameters can be specified:
    -serverName  ** Required
    -collectionUserName  ** Required if a custom username will be used
    -collectionUserPass  ** Required if a custom password will be used

        or

    -useDefaultCreds  ** Required if custom credentials are not desired

```

---

#### Grants

The user creation scripts will grant the appropriate permissions. If the non default user is used, the sysadmin role must be granted:

```sql
EXEC master..sp_addsrvrolemember @loginame = N'[username]', @rolename = N'sysadmin'
```

---

#### Notes

\*\*\* The option "-useDefaultCreds" create a user named "userfordma" and a default password contained in the script
