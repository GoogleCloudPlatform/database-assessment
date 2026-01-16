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
- `opdb__VERSION__{file_tag}.txt` (collector version)
- `opdb__{file_tag}_locale.txt`
- `opdb__defines__{file_tag}.csv`

CSV files use:

- Pipe (`|`) delimiter
- Uppercase headers
- Double-quoted string values
- UTF-8 encoding

## Manifest Format

Each line is:

```
{db_type}|{md5}|{filename}
```

The manifest is generated after CSV export so the checksums reflect the final files in the ZIP.
