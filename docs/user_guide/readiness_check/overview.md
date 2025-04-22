# Readiness Check Utility Overview

The Database Migration Assessment (DMA) Readiness Check utility is a command-line tool designed to analyze your source PostgreSQL database configuration and identify potential compatibility issues or necessary adjustments before migrating to Google Cloud SQL for PostgreSQL or AlloyDB for PostgreSQL.

## Purpose

Running the readiness check *before* initiating a migration can help you proactively address configuration problems, ensuring a smoother migration process. It checks various aspects of your source database against the requirements and recommendations for the target Google Cloud database service.

## What it Checks

Based on the collected data, the utility generates a report highlighting:

* **Version Compatibility:** Checks if your source PostgreSQL version is supported by the target service (Cloud SQL or AlloyDB).
* **DMS Compatibility:** Verifies the presence and configuration of necessary extensions, such as `pglogical`, which is crucial for logical replication used by Database Migration Service (DMS).
* **WAL Configuration:** Ensures the Write-Ahead Log (`wal_level`) is set correctly (typically to `logical`) for replication.
* **Replication Settings:** Examines parameters like `max_replication_slots`, `max_wal_senders`, and `max_worker_processes` to ensure they are sufficient for the migration process, potentially suggesting increases based on database count and parallelism.
* **Table Structure:** Identifies tables lacking primary keys, as this can limit Change Data Capture (CDC) replication (only `INSERT`s might be replicated).
* **Unsupported Features:** Checks for collations, extensions, or foreign data wrappers that might not be supported or migrated to the target environment.
* **Permissions:** (Implicitly) Requires appropriate user permissions to gather the necessary metadata.

## Output

The tool outputs a clear report, typically categorized by target service (Cloud SQL, AlloyDB), listing each check with a severity level:

* **PASS:** The check passed, no action needed.
* **WARNING:** Potential issue or recommendation; review is advised. May require adjustments depending on migration specifics (e.g., parallelism).
* **ACTION REQUIRED:** A configuration change is necessary for a successful migration.
* **ERROR:** A critical issue was found that blocks migration (e.g., unsupported source version for the target).

Each finding includes a description and often links to relevant Google Cloud documentation for more details on how to address it.

## Next Steps

* [Installation Guide](package-installation.md) - Learn how to install and run the utility.
