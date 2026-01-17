# Copyright 2024 Google LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Collection file writer for exporting DuckDB data to shell-script compatible format.

This module provides functionality to export collected database assessment data
from DuckDB to CSV files in a format compatible with the shell script collector output.
"""

from __future__ import annotations

import hashlib
import locale
import os
import zipfile
from datetime import datetime, timezone
from pathlib import Path  # noqa: TC003 - Path used at runtime
from typing import TYPE_CHECKING, Final, Literal

if TYPE_CHECKING:
    from sqlspec.adapters.duckdb import DuckDBDriver


# Mapping from DuckDB table/view names to shell script CSV file names
# Format: table_name -> csv_basename (without opdb__pg_ prefix and _tag suffix)
POSTGRES_TABLE_MAPPINGS: Final[dict[str, str]] = {
    "collection_postgres_applications": "applications",
    "collection_postgres_aws_extension_dependency": "aws_extension_dependency",
    "collection_postgres_aws_oracle_exists": "aws_oracle_exists",
    "collection_postgres_bg_writer_stats": "bg_writer_stats",
    "collection_postgres_calculated_metrics": "calculated_metrics",
    "collection_postgres_database_details": "database_details",
    "collection_postgres_data_types": "data_types",
    "collection_postgres_extensions": "extensions",
    "collection_postgres_index_details": "index_details",
    "collection_postgres_replication_slots": "replication_slots",
    "collection_postgres_replication_stats": "replication_stats",
    "collection_postgres_schema_details": "schema_details",
    "collection_postgres_schema_objects": "schema_objects",
    "collection_postgres_settings": "settings",
    "collection_postgres_source_details": "source_details",
    "collection_postgres_table_details": "table_details",
    "collection_postgres_db_machine_specs": "db_machine_specs",
    "collection_postgres_replication_role": "privileges",
    # Privilege tables - grouped under pglogical checks
    "collection_postgres_pglogical_privileges": "pglogical_privileges",
    "collection_postgres_pglogical_schema_usage_privilege": "pglogical_schema_usage_privilege",
    "collection_postgres_user_schemas_without_privilege": "user_schemas_without_privilege",
    "collection_postgres_user_tables_without_privilege": "user_tables_without_privilege",
    "collection_postgres_user_views_without_privilege": "user_views_without_privilege",
    "collection_postgres_user_sequences_without_privilege": "user_sequences_without_privilege",
}


class CollectionFileWriter:
    """Exports DuckDB collection data to shell-script compatible CSV/ZIP format.

    This class handles exporting collected database assessment data from DuckDB
    to the same CSV format produced by the shell script collectors, enabling
    compatibility with downstream processing tools.

    The output format matches:
    - Pipe-delimited CSV files
    - Double-quoted string values
    - Uppercase column headers
    - Manifest file with MD5 checksums
    - ZIP archive with all collection files
    """

    def __init__(
        self,
        driver: "DuckDBDriver",
        db_type: Literal["POSTGRES"] = "POSTGRES",
        db_version: str = "",
        dma_version: str = "4.3.45",
        hostname: str = "localhost",
        port: int = 5432,
        database: str = "postgres",
        manual_id: str | None = None,
    ) -> None:
        """Initialize the collection file writer.

        Args:
            driver: SQLSpec DuckDB driver with collected data.
            db_type: Source database type (currently only POSTGRES).
            db_version: Source database version number (e.g., "150000").
            dma_version: DMA collector version string.
            hostname: Source database hostname.
            port: Source database port.
            database: Source database name.
        """
        self.driver = driver
        self.db_type = db_type
        self.db_version = db_version
        self.dma_version = dma_version
        self.hostname = hostname
        self.port = port
        self.database = database
        self.manual_id = manual_id
        self._table_mappings = self._get_table_mappings()
        self._resolved_db_version: str | None = None

    def _get_table_mappings(self) -> dict[str, str]:
        """Get table-to-filename mappings for the current database type.

        Returns:
            Dictionary mapping DuckDB table names to CSV file basenames.
        """
        if self.db_type == "POSTGRES":
            return POSTGRES_TABLE_MAPPINGS
        msg = f"Unsupported database type: {self.db_type}"
        raise ValueError(msg)

    def get_file_tag(self) -> str:
        """Generate the file tag used in output filenames.

        The file tag format matches the shell script:
        {db_version}_{dma_version}_{hostname}-{port}_{database}_{database}_{YYMMDDHHmmss}

        Returns:
            File tag string for use in output filenames.
        """
        timestamp = datetime.now(tz=timezone.utc).strftime("%y%m%d%H%M%S")
        version_tag = self._resolve_db_version_tag()
        # Sanitize hostname (replace dots with dashes for filename safety)
        safe_hostname = self.hostname.replace(".", "-")
        # Sanitize database name
        safe_database = self.database.replace("/", "_").replace("\\", "_")

        return f"{version_tag}_{self.dma_version}_{safe_hostname}-{self.port}_{safe_database}_{safe_database}_{timestamp}"

    def _resolve_db_version_tag(self) -> str:
        """Resolve the numeric database version tag for filenames."""
        if self._resolved_db_version:
            return self._resolved_db_version

        if self.db_version and str(self.db_version).isdigit():
            self._resolved_db_version = str(self.db_version)
            return self._resolved_db_version

        # Try to derive from calculated metrics table when available.
        try:
            value = self.driver.select_value(
                "SELECT metric_value FROM collection_postgres_calculated_metrics "
                "WHERE metric_name = 'VERSION_NUM' LIMIT 1"
            )
            if value:
                self._resolved_db_version = str(value)
                return self._resolved_db_version
        except (RuntimeError, ValueError):
            pass

        if self.db_version:
            digits = "".join(ch for ch in str(self.db_version) if ch.isdigit())
            if digits:
                self._resolved_db_version = digits
                return self._resolved_db_version

        self._resolved_db_version = "unknown"
        return self._resolved_db_version

    @staticmethod
    def _get_db_major(version_tag: str) -> str:
        if not version_tag or version_tag == "unknown":
            return "unknown"
        return version_tag[:2] if len(version_tag) >= 2 else version_tag

    def _get_csv_filename(self, table_name: str, file_tag: str) -> str:
        """Generate the CSV filename for a given table.

        Args:
            table_name: DuckDB table/view name.
            file_tag: File tag from get_file_tag().

        Returns:
            CSV filename in shell script format.
        """
        csv_basename = self._table_mappings.get(table_name, table_name)
        return f"opdb__pg_{csv_basename}_{file_tag}.csv"

    @staticmethod
    def _quote_value(value: object) -> str:
        """Quote a value for CSV output, matching shell script format.

        String values are wrapped in double quotes. Inner double quotes
        are replaced with single quotes (matching chr(34)/chr(39) in SQL).

        Args:
            value: Value to quote.

        Returns:
            Quoted string representation.
        """
        if value is None:
            return ""
        if isinstance(value, bool):
            return str(value).lower()
        if isinstance(value, str):
            # Replace inner double quotes with single quotes (matches shell SQL)
            escaped = value.replace('"', "'")
            return f'"{escaped}"'
        # Numeric and other types don't need quoting
        return str(value)

    def export_table_to_csv(
        self,
        table_name: str,
        output_dir: Path,
        file_tag: str,
    ) -> Path | None:
        """Export a single DuckDB table/view to CSV using DuckDB's COPY statement.

        Args:
            table_name: DuckDB table/view name to export.
            output_dir: Directory for output file.
            file_tag: File tag for filename.

        Returns:
            Path to created CSV file, or None if table is empty/missing.
        """
        # Check if table exists and has data
        # Note: table_name comes from internal POSTGRES_TABLE_MAPPINGS, not user input
        try:
            count_result = self.driver.select_value(f"SELECT COUNT(*) FROM {table_name}")  # noqa: S608
            if not count_result or count_result == 0:
                if table_name == "collection_postgres_db_machine_specs":
                    return self._write_db_machine_specs_placeholder(output_dir, file_tag)
                return None
        except (RuntimeError, ValueError):  # DuckDB raises these for missing tables
            if table_name == "collection_postgres_db_machine_specs":
                return self._write_db_machine_specs_placeholder(output_dir, file_tag)
            return None

        # Generate filename and path
        filename = self._get_csv_filename(table_name, file_tag)
        filepath = output_dir / filename

        # Use DuckDB COPY to export CSV with proper quoting and pipe delimiter
        # Note: table_name is from internal POSTGRES_TABLE_MAPPINGS, not user input
        self.driver.execute(
            f"COPY {table_name} TO '{filepath!s}' (FORMAT CSV, DELIMITER '|', HEADER TRUE, QUOTE '\"', FORCE_QUOTE *)"
        )

        # Post-process to uppercase headers (DuckDB doesn't support this natively)
        self._uppercase_csv_headers(filepath)

        return filepath

    def _get_collection_identifiers(self) -> tuple[str, str, str]:
        """Fetch identifiers from any available collection table."""
        for table in ("collection_postgres_calculated_metrics", "collection_postgres_source_details"):
            try:
                rows = self.driver.select(
                    f"SELECT pkey, dma_source_id, dma_manual_id FROM {table} LIMIT 1"  # noqa: S608
                )
            except (RuntimeError, ValueError):
                continue
            if rows:
                row = rows[0]
                pkey = str(row.get("pkey") or "")
                source_id = str(row.get("dma_source_id") or "")
                manual_id = str(row.get("dma_manual_id") or "")
                if manual_id:
                    self.manual_id = manual_id
                return pkey, source_id, manual_id
        return "", "", self.manual_id or ""

    def _write_db_machine_specs_placeholder(self, output_dir: Path, file_tag: str) -> Path:
        """Create a placeholder db_machine_specs CSV when data is unavailable."""
        filename = f"opdb__pg_db_machine_specs_{file_tag}.csv"
        filepath = output_dir / filename
        header = (
            "PKEY|DMA_SOURCE_ID|DMA_MANUAL_ID|MACHINE_NAME|PHYSICAL_CPU_COUNT|LOGICAL_CPU_COUNT|"
            "TOTAL_OS_MEMORY_MB|TOTAL_SIZE_BYTES|USED_SIZE_BYTES|PRIMARY_MAC|IP_ADDRESSES"
        )
        pkey, source_id, manual_id = self._get_collection_identifiers()
        row = "|".join(
            [
                self._quote_value(pkey),
                self._quote_value(source_id),
                self._quote_value(manual_id),
                self._quote_value(self.hostname),
                self._quote_value(""),
                self._quote_value(""),
                self._quote_value(""),
                self._quote_value(""),
                self._quote_value(""),
                self._quote_value(""),
                self._quote_value(""),
            ]
        )
        filepath.write_text(f"{header}\n{row}\n", encoding="utf-8")
        return filepath

    @staticmethod
    def _uppercase_csv_headers(filepath: Path) -> None:
        """Convert CSV header row to uppercase.

        Args:
            filepath: Path to CSV file to modify.
        """
        content = filepath.read_text(encoding="utf-8")
        lines = content.split("\n")
        if lines:
            # Uppercase the first line (header)
            lines[0] = lines[0].upper()
            filepath.write_text("\n".join(lines), encoding="utf-8")

    def create_manifest(self, files: list[Path], output_dir: Path, file_tag: str) -> Path:
        """Create manifest file with MD5 checksums.

        The manifest format matches shell script:
        {db_type}|{md5}|{filename}

        Args:
            files: List of files to include in manifest.
            output_dir: Directory for manifest file.
            file_tag: File tag for manifest filename.

        Returns:
            Path to created manifest file.
        """
        manifest_path = output_dir / f"opdb__manifest__{file_tag}.txt"

        with manifest_path.open("w", encoding="utf-8") as f:
            for filepath in sorted(files):
                md5_hash = self._compute_md5(filepath)
                # Use db_type lowercase to match shell script
                f.write(f"{self.db_type.lower()}|{md5_hash}|{filepath.name}\n")

        return manifest_path

    @staticmethod
    def _compute_md5(filepath: Path) -> str:
        """Compute MD5 hash of a file.

        Args:
            filepath: Path to file.

        Returns:
            MD5 hash as hex string.
        """
        md5 = hashlib.md5()  # noqa: S324
        with filepath.open("rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                md5.update(chunk)
        return md5.hexdigest()

    def _create_version_file(self, output_dir: Path, file_tag: str) -> Path:
        """Create version file matching shell script output name.

        Args:
            output_dir: Directory for version file.
            file_tag: File tag for filename.

        Returns:
            Path to created version file.
        """
        version_path = output_dir / f"opdb__{file_tag}_version.txt"
        with version_path.open("w", encoding="utf-8") as f:
            f.write(f"Database Migration Assessment Collector version {self.dma_version}\n")
        return version_path

    @staticmethod
    def _create_locale_file(output_dir: Path, file_tag: str) -> Path:
        """Create locale file with system locale information.

        Args:
            output_dir: Directory for locale file.
            file_tag: File tag for filename.

        Returns:
            Path to created locale file.
        """
        locale_path = output_dir / f"opdb__{file_tag}_locale.txt"
        with locale_path.open("w", encoding="utf-8") as f:
            def get_locale_setting(name: str, category: int | None, default: str = "") -> str:
                value = os.environ.get(name)
                if value is not None:
                    return value
                if category is None:
                    return default
                try:
                    loc = locale.getlocale(category)
                    if loc and loc[0]:
                        return f"{loc[0]}.{loc[1]}" if loc[1] else loc[0]
                except (TypeError, ValueError):
                    return default
                return default

            categories: list[tuple[str, int | None, str]] = [
                ("LANG", None, "en_US.UTF-8"),
                ("LC_CTYPE", locale.LC_CTYPE, ""),
                ("LC_NUMERIC", locale.LC_NUMERIC, ""),
                ("LC_TIME", locale.LC_TIME, ""),
                ("LC_COLLATE", locale.LC_COLLATE, ""),
                ("LC_MONETARY", locale.LC_MONETARY, ""),
                ("LC_MESSAGES", getattr(locale, "LC_MESSAGES", None), ""),
                ("LC_PAPER", getattr(locale, "LC_PAPER", None), ""),
                ("LC_NAME", getattr(locale, "LC_NAME", None), ""),
                ("LC_ADDRESS", getattr(locale, "LC_ADDRESS", None), ""),
                ("LC_TELEPHONE", getattr(locale, "LC_TELEPHONE", None), ""),
                ("LC_MEASUREMENT", getattr(locale, "LC_MEASUREMENT", None), ""),
                ("LC_IDENTIFICATION", getattr(locale, "LC_IDENTIFICATION", None), ""),
                ("LC_ALL", locale.LC_ALL, ""),
            ]

            for name, category, default in categories:
                value = get_locale_setting(name, category, default)
                f.write(f"{name}={value}\n")
        return locale_path

    def _create_defines_file(self, output_dir: Path, file_tag: str, zip_name: str) -> Path:
        """Create defines file with collection metadata.

        Args:
            output_dir: Directory for defines file.
            file_tag: File tag for filename.
            zip_name: Name of the output zip file.

        Returns:
            Path to created defines file.
        """
        defines_path = output_dir / f"opdb__defines__{file_tag}.csv"
        with defines_path.open("w", encoding="utf-8") as f:
            version_tag = self._resolve_db_version_tag()
            db_major = self._get_db_major(version_tag)
            manual_id = self.manual_id or "NA"
            f.write(f"dbmajor = {db_major}\n")
            f.write(f"MANUAL_ID : {manual_id}\n")
            f.write(f"zipfile_name: {zip_name}\n")
        return defines_path

    @staticmethod
    def _create_error_log_file(output_dir: Path, file_tag: str) -> Path:
        """Create an empty error log file to match shell script outputs."""
        error_log_path = output_dir / f"opdb__{file_tag}_errors.log"
        error_log_path.write_text("", encoding="utf-8")
        return error_log_path

    def create_collection_zip(self, output_dir: Path) -> Path:
        """Create a complete collection ZIP file.

        Exports all collection tables to CSV, creates manifest and metadata files,
        and packages everything into a ZIP archive matching shell script format.

        Args:
            output_dir: Directory for output files and ZIP.

        Returns:
            Path to created ZIP file.
        """
        output_dir.mkdir(parents=True, exist_ok=True)
        file_tag = self.get_file_tag()

        # Determine ZIP filename
        zip_name = f"opdb_{self.db_type.lower()}_{self.db_type.lower()}__{file_tag}.zip"
        zip_path = output_dir / zip_name

        # Export all tables
        exported_files: list[Path] = []
        for table_name in self._table_mappings:
            csv_path = self.export_table_to_csv(table_name, output_dir, file_tag)
            if csv_path:
                exported_files.append(csv_path)

        # Create metadata files
        version_file = self._create_version_file(output_dir, file_tag)
        locale_file = self._create_locale_file(output_dir, file_tag)
        defines_file = self._create_defines_file(output_dir, file_tag, zip_name)
        error_log_file = self._create_error_log_file(output_dir, file_tag)

        all_files = [*exported_files, version_file, locale_file, defines_file, error_log_file]

        # Create manifest (includes itself in the package but not in checksums)
        manifest_file = self.create_manifest(all_files, output_dir, file_tag)
        all_files.append(manifest_file)

        # Create ZIP archive
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for filepath in all_files:
                zf.write(filepath, filepath.name)

        # Clean up individual files (keep only ZIP)
        for filepath in all_files:
            filepath.unlink()

        return zip_path
