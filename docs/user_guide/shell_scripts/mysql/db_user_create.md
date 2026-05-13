# Database User Creation (Optional)

The collection scripts can be executed with any administrative account. Alternately, a new least-privileged user can be created for access using the following steps.

## Create User

Execute the following user preparation statements from a privileged client connection:

```sql
CREATE USER 'dmacollector'@'%' IDENTIFIED BY 'secure_password';
```

Please see the dedicated [Permissions](permissions.md) guide for detailed information regarding system catalog query requirements.
