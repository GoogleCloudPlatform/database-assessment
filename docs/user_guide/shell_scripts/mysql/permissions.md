# Create a user for Collection

 The collection scripts can be executed with any administrative account. Alternatively, create a new user with the minimum privileges required.
 Please see the [User Creation](db_user_create.md) page for information on how to create the user and grant required privileges.

## Permissions Required

Data collection harvests catalog metadata, auxiliary schema objects, and system statistics across all user databases. The following global database privileges are required for unconstrained script execution:

```sql
GRANT SELECT, PROCESS, EVENT, TRIGGER, SHOW VIEW,
  RESOURCE_GROUP_ADMIN ON *.* TO 'dmacollector'@'%';
```

### Notes

- **`SELECT`**: Ensures read visibility into all application table catalogs
  and basic `information_schema` structures.
- **`PROCESS`**: Required to harvest comprehensive thread execution metrics.
- **`EVENT` & `TRIGGER`**: Guarantees complete row visibility into scheduled
  events and database triggers defined across foreign user schemas.
- **`SHOW VIEW`**: Necessary to read full structural logic for compiled
  database views.
- **`RESOURCE_GROUP_ADMIN`**: Dynamic privilege required on MySQL 8.0+
  to view custom resource allocations.
