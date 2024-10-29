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

---

## Create User

If an existing user with SYSADMIN privileges wil not be used, from a command prompt, execute either of the following scripts depending on what type of authentication you currently use for your SYSADMIN user.

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

#### Notes
