# Database User Scripts (Optional)

The collection scripts can be executed with any DBA account. Alternately, a new user with the minimum privileges required for access with the following steps. Two scripts are provided to create the user one that uses SQL Authentication and another that uses Windows Authentication.

---

#### Grants Required

The user creation scripts will grant the appropriate permissions. If it is desired to utilize an existing user, the following grants must be granted. From the master database:

```sql
	GRANT VIEW SERVER STATE TO [username];
	GRANT SELECT ALL USER SECURABLES TO [username];
	GRANT VIEW ANY DATABASE TO [username];
	GRANT VIEW ANY DEFINITION TO [username];
	GRANT VIEW SERVER STATE TO [username];
```

In addition the user must also be mapped to all user databases, tempdb and master databases along with the following grant:

```sql
    use [user database name];
    CREATE USER [username] FOR LOGIN [username];
    GRANT VIEW DATABASE STATE TO [username];
```

---

## Create User

If an existing user with SYSADMIN privileges wil not be used, from a command prompt, execute either of the following scripts depending on what type of authentication you currently use for your SYSADMIN user.

#### SQL Authentication

```powershell

.\createUserForAssessmentWithSQLAuth.bat

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
.\createUserForAssessmentWithWindowsAuth.bat

The following parameters can be specified:
    -serverName  ** Required
    -collectionUserName  ** Required if a custom username will be used
    -collectionUserPass  ** Required if a custom password will be used

        or

    -useDefaultCreds  ** Required if custom credentials are not desired

```

---

#### Notes
