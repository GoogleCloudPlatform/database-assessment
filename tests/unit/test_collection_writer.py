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
"""Tests for CollectionFileWriter."""

from __future__ import annotations

import zipfile
from pathlib import Path
from typing import TYPE_CHECKING
from unittest.mock import MagicMock

import pytest

from dma.collector.util.collection_writer import CollectionFileWriter

if TYPE_CHECKING:
    pass


class TestQuoteValue:
    """Tests for the _quote_value static method."""

    def test_none_value(self) -> None:
        """None values should return empty string."""
        assert CollectionFileWriter._quote_value(None) == ""

    def test_boolean_true(self) -> None:
        """Boolean True should return lowercase 'true'."""
        assert CollectionFileWriter._quote_value(True) == "true"

    def test_boolean_false(self) -> None:
        """Boolean False should return lowercase 'false'."""
        assert CollectionFileWriter._quote_value(False) == "false"

    def test_string_simple(self) -> None:
        """Simple strings should be wrapped in double quotes."""
        assert CollectionFileWriter._quote_value("hello") == '"hello"'

    def test_string_with_double_quotes(self) -> None:
        """Inner double quotes should be replaced with single quotes."""
        assert CollectionFileWriter._quote_value('say "hello"') == "\"say 'hello'\""

    def test_integer(self) -> None:
        """Integers should not be quoted."""
        assert CollectionFileWriter._quote_value(42) == "42"

    def test_float(self) -> None:
        """Floats should not be quoted."""
        assert CollectionFileWriter._quote_value(3.14) == "3.14"


class TestGetFileTag:
    """Tests for the get_file_tag method."""

    def test_file_tag_format(self) -> None:
        """File tag should match expected format."""
        mock_driver = MagicMock()
        writer = CollectionFileWriter(
            driver=mock_driver,
            db_type="POSTGRES",
            db_version="150000",
            dma_version="4.3.45",
            hostname="localhost",
            port=5432,
            database="testdb",
        )
        tag = writer.get_file_tag()
        # Check format: {db_version}_{dma_version}_{hostname}-{port}_{database}_{database}_{timestamp}
        parts = tag.split("_")
        assert parts[0] == "150000"  # db_version
        assert parts[1] == "4.3.45"  # dma_version
        assert "localhost-5432" in tag  # hostname-port
        assert "testdb" in tag  # database appears twice

    def test_hostname_sanitization(self) -> None:
        """Dots in hostname should be replaced with dashes."""
        mock_driver = MagicMock()
        writer = CollectionFileWriter(
            driver=mock_driver,
            hostname="db.example.com",
            port=5432,
            database="test",
        )
        tag = writer.get_file_tag()
        assert "db-example-com-5432" in tag

    def test_database_sanitization(self) -> None:
        """Slashes in database name should be replaced with underscores."""
        mock_driver = MagicMock()
        writer = CollectionFileWriter(
            driver=mock_driver,
            hostname="localhost",
            port=5432,
            database="test/db",
        )
        tag = writer.get_file_tag()
        assert "test_db" in tag


class TestComputeMd5:
    """Tests for the _compute_md5 static method."""

    def test_md5_computation(self, tmp_path: Path) -> None:
        """MD5 should be computed correctly."""
        test_file = tmp_path / "test.txt"
        test_file.write_text("hello world")
        md5_hash = CollectionFileWriter._compute_md5(test_file)
        # Known MD5 of "hello world"
        assert md5_hash == "5eb63bbbe01eeed093cb22bb8f5acdc3"


class TestCreateManifest:
    """Tests for the create_manifest method."""

    def test_manifest_format(self, tmp_path: Path) -> None:
        """Manifest should follow the correct format."""
        mock_driver = MagicMock()
        writer = CollectionFileWriter(driver=mock_driver, db_type="POSTGRES")

        # Create test files
        file1 = tmp_path / "test1.csv"
        file1.write_text("col1|col2\nval1|val2")
        file2 = tmp_path / "test2.csv"
        file2.write_text("col1\nval1")

        manifest_path = writer.create_manifest([file1, file2], tmp_path, "test_tag")

        assert manifest_path.exists()
        content = manifest_path.read_text()
        lines = content.strip().split("\n")
        assert len(lines) == 2

        # Check format: {db_type}|{md5}|{filename}
        for line in lines:
            parts = line.split("|")
            assert len(parts) == 3
            assert parts[0] == "postgres"  # lowercase db_type
            assert len(parts[1]) == 32  # MD5 hash length


class TestExportTableToCsv:
    """Tests for export_table_to_csv method."""

    def test_empty_table_returns_none(self, tmp_path: Path) -> None:
        """Empty or missing tables should return None."""
        mock_driver = MagicMock()
        mock_driver.select_value.return_value = 0
        writer = CollectionFileWriter(driver=mock_driver)

        result = writer.export_table_to_csv(
            "collection_postgres_extensions",
            tmp_path,
            "test_tag",
        )
        assert result is None

    def test_missing_table_returns_none(self, tmp_path: Path) -> None:
        """Missing tables should return None."""
        mock_driver = MagicMock()
        mock_driver.select_value.side_effect = RuntimeError("Table not found")
        writer = CollectionFileWriter(driver=mock_driver)

        result = writer.export_table_to_csv(
            "collection_postgres_extensions",
            tmp_path,
            "test_tag",
        )
        assert result is None


class TestCreateCollectionZip:
    """Tests for create_collection_zip method."""

    def test_zip_creation(self, tmp_path: Path) -> None:
        """ZIP file should be created with expected structure."""
        mock_driver = MagicMock()
        # Simulate no tables having data
        mock_driver.select_value.return_value = 0
        writer = CollectionFileWriter(
            driver=mock_driver,
            db_type="POSTGRES",
            db_version="150000",
            dma_version="4.3.45",
            hostname="localhost",
            port=5432,
            database="testdb",
        )

        zip_path = writer.create_collection_zip(tmp_path)

        assert zip_path.exists()
        assert zip_path.suffix == ".zip"
        assert "opdb_postgres_postgres__" in zip_path.name

        # Check ZIP contents
        with zipfile.ZipFile(zip_path, "r") as zf:
            names = zf.namelist()
            # Should have manifest, version, locale, defines files
            assert any("manifest" in n for n in names)
            assert any("VERSION" in n for n in names)
            assert any("locale" in n for n in names)
            assert any("defines" in n for n in names)

    def test_zip_with_table_data(self, tmp_path: Path) -> None:
        """ZIP should include CSV files for tables with data."""
        mock_driver = MagicMock()

        # Simulate one table having data
        def select_value_side_effect(query: str) -> int:
            if "collection_postgres_calculated_metrics" in query:
                return 1
            return 0

        mock_driver.select_value.side_effect = select_value_side_effect

        # Mock the COPY command to actually create a CSV file
        def execute_side_effect(query: str) -> None:
            if "COPY collection_postgres_calculated_metrics TO" in query:
                # Extract the file path from the COPY command
                import re

                match = re.search(r"TO '([^']+)'", query)
                if match:
                    filepath = Path(match.group(1))
                    # Create a mock CSV file
                    filepath.write_text('pkey|metric_name|metric_value\n"key1"|"VERSION"|"15.0"\n')

        mock_driver.execute.side_effect = execute_side_effect

        writer = CollectionFileWriter(
            driver=mock_driver,
            db_type="POSTGRES",
            db_version="150000",
        )

        zip_path = writer.create_collection_zip(tmp_path)

        with zipfile.ZipFile(zip_path, "r") as zf:
            names = zf.namelist()
            # Should have a calculated_metrics CSV
            csv_files = [n for n in names if n.endswith(".csv") and "calculated_metrics" in n]
            assert len(csv_files) == 1

            # Check CSV content
            with zf.open(csv_files[0]) as f:
                content = f.read().decode("utf-8")
                assert "PKEY|METRIC_NAME|METRIC_VALUE" in content
                assert '"key1"|"VERSION"|"15.0"' in content
