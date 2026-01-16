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
from __future__ import annotations

import hashlib
import tarfile
import zipfile
from pathlib import Path
from typing import TYPE_CHECKING

import pytest

if TYPE_CHECKING:
    from collections.abc import Iterator

    from tests.lib.collector_build import CollectorArtifacts
    from tests.lib.script_executor import CollectorResult, ScriptExecutor
    from tools.postgres.database import PostgreSQLDatabase


pytestmark = [
    pytest.mark.script_test,
    pytest.mark.postgres,
    pytest.mark.integration,
    pytest.mark.slow,
]


def _iter_archive_members(archive_path: Path) -> Iterator[tuple[str, bytes]]:
    if archive_path.suffixes[-2:] == [".tar", ".gz"] or archive_path.suffix == ".gz":
        with tarfile.open(archive_path, "r:gz") as tf:
            for member in tf.getmembers():
                if not member.isfile():
                    continue
                file_obj = tf.extractfile(member)
                if file_obj is None:
                    continue
                yield member.name, file_obj.read()
    else:
        with zipfile.ZipFile(archive_path) as zf:
            for name in zf.namelist():
                if name.endswith("/"):
                    continue
                yield name, zf.read(name)


def _read_archive_file(archive_path: Path, filename: str) -> bytes:
    for name, data in _iter_archive_members(archive_path):
        if name == filename:
            return data
    raise FileNotFoundError(filename)


@pytest.fixture(scope="session")
def postgres_connection_string(postgres_collector_db: PostgreSQLDatabase) -> str:
    config = postgres_collector_db.config
    return f"{config.postgres_user}/{config.postgres_password}@//localhost:{config.container_port}/{config.postgres_db}"


@pytest.fixture(scope="session")
def postgres_script_result(
    collector_artifacts: CollectorArtifacts,
    postgres_collector_db: PostgreSQLDatabase,
    script_executor: ScriptExecutor,
    postgres_connection_string: str,
) -> CollectorResult:
    return script_executor.run_collector(
        container_name=postgres_collector_db.config.container_name,
        zip_path=collector_artifacts.postgres_zip,
        db_type="postgres",
        connection_string=postgres_connection_string,
        extra_args=["--allDbs", "N"],
        timeout=300,
    )


@pytest.fixture(scope="session")
def postgres_multi_db_ready(
    postgres_collector_db: PostgreSQLDatabase,
    script_executor: ScriptExecutor,
) -> None:
    config = postgres_collector_db.config
    script_executor.exec_in_container(
        config.container_name,
        [
            "bash",
            "-c",
            (
                "PGPASSWORD={password} psql -U {user} -d {db} "
                "-c \"CREATE DATABASE dma_test_extra\" || true"
            ).format(password=config.postgres_password, user=config.postgres_user, db=config.postgres_db),
        ],
    )


@pytest.fixture(scope="session")
def postgres_script_result_all_dbs(
    postgres_multi_db_ready: None,
    collector_artifacts: CollectorArtifacts,
    postgres_collector_db: PostgreSQLDatabase,
    script_executor: ScriptExecutor,
    postgres_connection_string: str,
) -> CollectorResult:
    return script_executor.run_collector(
        container_name=postgres_collector_db.config.container_name,
        zip_path=collector_artifacts.postgres_zip,
        db_type="postgres",
        connection_string=postgres_connection_string,
        extra_args=["--allDbs", "Y"],
        timeout=300,
    )


class TestPostgresCollectionScript:
    def test_postgres_collector_executes_successfully(self, postgres_script_result: CollectorResult) -> None:
        assert postgres_script_result.exit_code == 0, (
            f"Script failed.\nstdout:\n{postgres_script_result.stdout}\n\nstderr:\n{postgres_script_result.stderr}"
        )

    def test_postgres_collector_creates_output_archive(self, postgres_script_result: CollectorResult) -> None:
        assert postgres_script_result.output_archive is not None, "No output archive created"
        assert postgres_script_result.output_archive.stat().st_size > 0, "Output archive is empty"

    def test_postgres_collector_csv_files_valid(self, postgres_script_result: CollectorResult) -> None:
        assert postgres_script_result.output_archive is not None
        csv_files = [
            name
            for name, _ in _iter_archive_members(postgres_script_result.output_archive)
            if name.endswith(".csv") and "defines" not in name
        ]
        assert csv_files, "No CSV files found in archive"
        for csv_name in csv_files:
            content = _read_archive_file(postgres_script_result.output_archive, csv_name).decode("utf-8")
            header = content.splitlines()[0] if content else ""
            assert "|" in header, f"CSV {csv_name} header missing pipe delimiter"

    def test_postgres_collector_manifest_checksums(self, postgres_script_result: CollectorResult) -> None:
        assert postgres_script_result.output_archive is not None
        manifest_name = next(
            name
            for name, _ in _iter_archive_members(postgres_script_result.output_archive)
            if "manifest" in name and name.endswith(".txt")
        )
        manifest_content = _read_archive_file(postgres_script_result.output_archive, manifest_name).decode("utf-8")
        for line in manifest_content.strip().splitlines():
            db_type, expected_md5, filename = line.split("|", maxsplit=2)
            data = _read_archive_file(postgres_script_result.output_archive, filename)
            actual_md5 = hashlib.md5(data).hexdigest()  # noqa: S324
            assert db_type == "postgres"
            assert actual_md5 == expected_md5

    def test_postgres_collector_all_dbs_mode(self, postgres_script_result_all_dbs: CollectorResult) -> None:
        assert postgres_script_result_all_dbs.output_dir is not None
        archives = list(postgres_script_result_all_dbs.output_dir.glob("*.zip")) + list(
            postgres_script_result_all_dbs.output_dir.glob("*.tar.gz")
        )
        assert len(archives) > 1, "Expected multiple archives when --allDbs Y is set"
        for archive in archives:
            members = list(_iter_archive_members(archive))
            csv_files = [name for name, _ in members if name.endswith(".csv") and "defines" not in name]
            manifests = [name for name, _ in members if "manifest" in name and name.endswith(".txt")]
            assert csv_files, f"No CSV files found in {archive.name}"
            assert manifests, f"No manifest file found in {archive.name}"
