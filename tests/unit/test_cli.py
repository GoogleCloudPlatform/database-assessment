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
from click.testing import CliRunner

from dma.cli.main import app

# def test_collect_data() -> None:
#     runner = CliRunner()
#     result = runner.invoke(app, ["collect"])
#     assert result.exit_code == 0


def test_readiness_check() -> None:
    runner = CliRunner()
    result = runner.invoke(app, ["readiness-check", "--help"])
    assert result.exit_code == 0
    assert "--single-db" in result.output


class TestReadinessCheckSslOptions:
    """Tests for SSL CLI options on readiness-check command."""

    def test_ssl_mode_option_exists(self) -> None:
        """readiness-check should accept --ssl-mode option."""
        runner = CliRunner()
        result = runner.invoke(app, ["readiness-check", "--help"])
        assert "--ssl-mode" in result.output

    def test_ssl_mode_choices(self) -> None:
        """--ssl-mode should show valid choices in help."""
        runner = CliRunner()
        result = runner.invoke(app, ["readiness-check", "--help"])
        assert "disable" in result.output
        assert "require" in result.output
        assert "verify-full" in result.output

    def test_ssl_cert_option_exists(self) -> None:
        """readiness-check should accept --ssl-cert option."""
        runner = CliRunner()
        result = runner.invoke(app, ["readiness-check", "--help"])
        assert "--ssl-cert" in result.output

    def test_ssl_key_option_exists(self) -> None:
        """readiness-check should accept --ssl-key option."""
        runner = CliRunner()
        result = runner.invoke(app, ["readiness-check", "--help"])
        assert "--ssl-key" in result.output

    def test_ssl_root_cert_option_exists(self) -> None:
        """readiness-check should accept --ssl-root-cert option."""
        runner = CliRunner()
        result = runner.invoke(app, ["readiness-check", "--help"])
        assert "--ssl-root-cert" in result.output


def test_collect_data_single_db_option_exists() -> None:
    runner = CliRunner()
    result = runner.invoke(app, ["collect-data", "--help"])
    assert result.exit_code == 0
    assert "--single-db" in result.output
