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

import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

import filelock
import pytest

ARTIFACT_NAMES = {
    "postgres": "db-migration-assessment-collection-scripts-postgres.zip",
    "mysql": "db-migration-assessment-collection-scripts-mysql.zip",
    "oracle": "db-migration-assessment-collection-scripts-oracle.zip",
    "sqlserver": "db-migration-assessment-collection-scripts-sqlserver.zip",
}


@dataclass
class CollectorArtifacts:
    """Built collector artifacts for script tests."""

    dist_dir: Path
    postgres_zip: Path
    mysql_zip: Path | None
    oracle_zip: Path | None
    sqlserver_zip: Path | None


def _artifact_path(dist_dir: Path, key: str) -> Path:
    return dist_dir / ARTIFACT_NAMES[key]


def build_collector_artifacts(project_root: Path) -> CollectorArtifacts:
    """Build collector artifacts using make build-collector.

    Uses file locking to ensure a single build across pytest-xdist workers.
    """
    lock_path = Path(tempfile.gettempdir()) / "dma-collector-build.lock"
    dist_dir = project_root / "dist"

    with filelock.FileLock(str(lock_path)):
        postgres_zip = _artifact_path(dist_dir, "postgres")
        mysql_zip = _artifact_path(dist_dir, "mysql")
        oracle_zip = _artifact_path(dist_dir, "oracle")
        sqlserver_zip = _artifact_path(dist_dir, "sqlserver")

        if not postgres_zip.exists():
            result = subprocess.run(
                ["make", "build-collector"],
                cwd=project_root,
                capture_output=True,
                text=True,
                timeout=300,
                check=False,
            )
            if result.returncode != 0:
                raise RuntimeError(
                    "Collector build failed.\n"
                    f"stdout:\n{result.stdout}\n\nstderr:\n{result.stderr}"
                )

        if not postgres_zip.exists():
            raise RuntimeError(f"Collector build did not produce {postgres_zip}")

        return CollectorArtifacts(
            dist_dir=dist_dir,
            postgres_zip=postgres_zip,
            mysql_zip=mysql_zip if mysql_zip.exists() else None,
            oracle_zip=oracle_zip if oracle_zip.exists() else None,
            sqlserver_zip=sqlserver_zip if sqlserver_zip.exists() else None,
        )


@pytest.fixture(scope="session")
def collector_artifacts() -> CollectorArtifacts:
    project_root = Path(__file__).resolve().parents[2]
    return build_collector_artifacts(project_root)
