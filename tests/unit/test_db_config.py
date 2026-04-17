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
"""Tests for database configuration module."""

from __future__ import annotations

from dma.lib.db.config import SourceInfo, create_postgres_adbc_config


class TestSourceInfo:
    """Tests for SourceInfo dataclass."""

    def test_source_info_without_ssl(self) -> None:
        """SourceInfo should work without SSL parameters."""
        src_info = SourceInfo(
            db_type="POSTGRES",
            username="testuser",
            password="testpass",
            hostname="localhost",
            port=5432,
        )
        assert src_info.ssl_mode is None
        assert src_info.ssl_cert is None
        assert src_info.ssl_key is None
        assert src_info.ssl_root_cert is None

    def test_source_info_with_ssl_mode(self) -> None:
        """SourceInfo should accept ssl_mode parameter."""
        src_info = SourceInfo(
            db_type="POSTGRES",
            username="testuser",
            password="testpass",
            hostname="localhost",
            port=5432,
            ssl_mode="require",
        )
        assert src_info.ssl_mode == "require"

    def test_source_info_with_all_ssl_params(self) -> None:
        """SourceInfo should accept all SSL parameters."""
        src_info = SourceInfo(
            db_type="POSTGRES",
            username="testuser",
            password="testpass",
            hostname="localhost",
            port=5432,
            ssl_mode="verify-full",
            ssl_cert="/path/to/client.crt",
            ssl_key="/path/to/client.key",
            ssl_root_cert="/path/to/ca.crt",
        )
        assert src_info.ssl_mode == "verify-full"
        assert src_info.ssl_cert == "/path/to/client.crt"
        assert src_info.ssl_key == "/path/to/client.key"
        assert src_info.ssl_root_cert == "/path/to/ca.crt"


class TestCreatePostgresAdbcConfig:
    """Tests for create_postgres_adbc_config function."""

    def test_basic_uri_without_ssl(self) -> None:
        """Config should generate basic URI without SSL parameters."""
        src_info = SourceInfo(
            db_type="POSTGRES",
            username="testuser",
            password="testpass",
            hostname="localhost",
            port=5432,
        )
        config = create_postgres_adbc_config(src_info, "testdb")
        uri = config.connection_config["uri"]
        assert uri == "postgresql://testuser:testpass@localhost:5432/testdb"
        assert "?" not in uri  # No query string

    def test_uri_with_ssl_mode_only(self) -> None:
        """Config should include sslmode in URI query string."""
        src_info = SourceInfo(
            db_type="POSTGRES",
            username="testuser",
            password="testpass",
            hostname="localhost",
            port=5432,
            ssl_mode="require",
        )
        config = create_postgres_adbc_config(src_info, "testdb")
        uri = config.connection_config["uri"]
        assert "?sslmode=require" in uri

    def test_uri_with_ssl_cert_and_key(self) -> None:
        """Config should include SSL cert and key paths in URI."""
        src_info = SourceInfo(
            db_type="POSTGRES",
            username="testuser",
            password="testpass",
            hostname="localhost",
            port=5432,
            ssl_mode="verify-ca",
            ssl_cert="/path/to/client.crt",
            ssl_key="/path/to/client.key",
        )
        config = create_postgres_adbc_config(src_info, "testdb")
        uri = config.connection_config["uri"]
        assert "sslmode=verify-ca" in uri
        assert "sslcert=/path/to/client.crt" in uri
        assert "sslkey=/path/to/client.key" in uri

    def test_uri_with_all_ssl_params(self) -> None:
        """Config should include all SSL parameters in URI."""
        src_info = SourceInfo(
            db_type="POSTGRES",
            username="testuser",
            password="testpass",
            hostname="localhost",
            port=5432,
            ssl_mode="verify-full",
            ssl_cert="/path/to/client.crt",
            ssl_key="/path/to/client.key",
            ssl_root_cert="/path/to/ca.crt",
        )
        config = create_postgres_adbc_config(src_info, "testdb")
        uri = config.connection_config["uri"]
        assert "sslmode=verify-full" in uri
        assert "sslcert=/path/to/client.crt" in uri
        assert "sslkey=/path/to/client.key" in uri
        assert "sslrootcert=/path/to/ca.crt" in uri
        # All params should be joined with &
        assert uri.count("&") == 3  # 4 params = 3 &'s

    def test_uri_with_partial_ssl_params(self) -> None:
        """Config should only include provided SSL parameters."""
        src_info = SourceInfo(
            db_type="POSTGRES",
            username="testuser",
            password="testpass",
            hostname="localhost",
            port=5432,
            ssl_root_cert="/path/to/ca.crt",
        )
        config = create_postgres_adbc_config(src_info, "testdb")
        uri = config.connection_config["uri"]
        # Should only have sslrootcert
        assert "sslrootcert=/path/to/ca.crt" in uri
        assert "sslmode" not in uri
        assert "sslcert" not in uri
        assert "sslkey" not in uri
