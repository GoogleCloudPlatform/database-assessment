# Collection Zip Format

The Python collector can emit a shell-script compatible collection ZIP (`--output-zip`). This format matches what downstream tooling expects from `scripts/collector/*/collect-data.sh`.

## Naming

```
opdb_{db_type}_{db_type}__{file_tag}.zip
```

`file_tag` is built from the database version, DMA version, host/port, database name, and a UTC timestamp.

## Contents

Each ZIP includes:

- CSV files for each collected table
- `opdb__manifest__{file_tag}.txt` with MD5 checksums
- `opdb__{file_tag}_version.txt` (collector version)
- `opdb__{file_tag}_locale.txt`
- `opdb__defines__{file_tag}.csv`
- `opdb__{file_tag}_errors.log` (empty when no errors)

CSV files use:

- Pipe (`|`) delimiter
- Uppercase headers
- Double-quoted string values
- UTF-8 encoding

## Machine Specs (db_machine_specs)

The shell script only populates machine specs when it can confirm it is running
on the database host (local host match or SSH access). The Python collector does
not collect machine specs yet; it emits a placeholder `opdb__pg_db_machine_specs_*`
row with empty metrics to preserve ZIP compatibility. Adding opt-in SSH-based
collection is still pending.

## Manifest Format

Each line is:

```
{db_type}|{md5}|{filename}
```

The manifest is generated after CSV export so the checksums reflect the final files in the ZIP.
