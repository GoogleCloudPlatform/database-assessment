# Database User Creation (Optional)

The collection scripts can be executed with the default postgres account. Alternately, a new least-privileged user can be created for access using the following steps.

## Create User

Execute the following statements using a superuser connection (e.g., via `psql`):

```sql
CREATE USER dmacollector WITH PASSWORD 'secure_password';
```

Please see the dedicated [Permissions](permissions.md) guide for detailed information regarding system catalog query requirements.
