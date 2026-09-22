Google Cloud Database Migration Assessment (DMA) - IBM DB2 Collector
====================================================================

The DB2 Collector extracts metadata, configuration, schema objects, time-series performance,
and feature usage from IBM DB2 databases (DB2 LUW for Linux, AIX, Windows, and DB2 for z/OS)
to evaluate cloud migration feasibility to Google Cloud (Cloud SQL, AlloyDB, Bare Metal Solution, BigQuery).

Prerequisites
-------------
1. IBM DB2 Command Line Processor ('db2' binary) must be installed and sourced in PATH.
2. Standard OS tools available: grep, sed, awk, cut, tr, tar, md5sum (or md5/csum).
3. Network reachability to target DB2 instance (Default port: 50000).

Permissions Setup
-----------------
To grant the necessary permissions to an existing or new assessment user, run:
  ./grant_permissions.sh --database <database_name> --username <target_user> \
     --superUser <admin_user> --superPassword <admin_pass> [--host <host> --port <port>]

Or execute the SQL script in sql/setup/grant_permissions.sql directly as a DBA/SYSADM.

Usage
-----
Run the collector from the scripts/collector/db2 directory:

Local Execution (on DB2 host):
  ./collect-data.sh --database SAMPLE --user dma_collector --password SecretPassword123

Remote Execution (over TCP/IP):
  ./collect-data.sh --host db2host.example.com --port 50000 --database SAMPLE --user dma_collector --password SecretPassword123

Alternative Connection String:
  ./collect-data.sh --connectionStr "dma_collector/SecretPassword123@//db2host.example.com:50000/SAMPLE"

Optional Parameters:
  --manualUniqueId <tag>   Custom customer identification tag.
  --vmUser <os_user>       SSH OS user for remote hardware discovery.

Output
------
Upon completion, the collector packages the extract files into:
  output/opdb_db2__<hostname>_<dbname>_<timestamp>.zip

The archive contains:
  1. opdb__db2_db_machine_specs_<tag>.csv       (Host CPU/Memory/Disk specs)
  2. opdb__db2_db_instances_<tag>.csv          (Instance / DPF node information)
  3. opdb__db2_databases_<tag>.csv             (Database-level metadata & sizing)
  4. opdb__db2_db_configurations_<tag>.csv     (Database and DBM configurations)
  5. opdb__db2_schema_objects_<tag>.csv        (Unified wide object profile)
  6. opdb__db2_performance_metrics_<tag>.csv   (Time-series performance metrics)
  7. opdb__db2_features_<tag>.csv              (Feature matrix & migration blockers)
  8. opdb__db2_eoj_<tag>.csv                   (End of job verification marker)
  9. opdb__db2_manifest_<tag>.txt              (MD5 verification manifest)
