## Permissions Required

The following permissions and built-in roles are required for full script execution across all targeted databases:

```sql
GRANT CONNECT ON DATABASE postgres TO dmacollector;
GRANT pg_read_all_stats TO dmacollector;
GRANT pg_read_all_settings TO dmacollector;
```

> **Note**: The `pg_read_all_stats` and `pg_read_all_settings` roles are available in PostgreSQL 10 and newer, granting non-superusers access to comprehensive system metadata and monitoring views.
