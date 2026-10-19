# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Session-scoped builder for packaged database collection script archives."""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

import filelock
import pytest

__all__ = [
    "ARTIFACT_NAMES",
    "CollectorArtifacts",
    "build_collector_artifacts",
    "collector_artifacts",
]

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
    mysql_zip: Path
    oracle_zip: Path
    sqlserver_zip: Path


def build_collector_artifacts(project_root: Path) -> CollectorArtifacts:
    """Build collector artifacts using make build-collector.

    Uses double-checked file locking and a per-session marker file so that
    collector archives are built once per test session across pytest-xdist workers.
    """
    uid = os.environ.get("DMA_TEST_RUN_UID", "default")
    temp_root = Path(tempfile.gettempdir())
    lock_path = temp_root / f"dma-collector-build-{uid}.lock"
    marker_path = temp_root / f"dma-collector-build-{uid}.done"
    dist_dir = project_root / "dist"
    postgres_zip = _artifact_path(dist_dir, "postgres")
    mysql_zip = _artifact_path(dist_dir, "mysql")
    oracle_zip = _artifact_path(dist_dir, "oracle")
    sqlserver_zip = _artifact_path(dist_dir, "sqlserver")
    expected_zips = (postgres_zip, mysql_zip, oracle_zip, sqlserver_zip)

    all_exist = all(p.exists() for p in expected_zips)
    if not (marker_path.exists() and all_exist):
        with filelock.FileLock(str(lock_path), timeout=300):
            all_exist = all(p.exists() for p in expected_zips)
            if not (marker_path.exists() and all_exist):
                make_cmd = shutil.which("make") or "make"
                result = subprocess.run(
                    [make_cmd, "build-collector"],
                    cwd=project_root,
                    capture_output=True,
                    text=True,
                    timeout=300,
                    check=False,
                )
                if result.returncode != 0:
                    err_msg = f"Collector build failed.\nstdout:\n{result.stdout}\n\nstderr:\n{result.stderr}"
                    raise RuntimeError(err_msg)

                missing = [str(p) for p in expected_zips if not p.exists()]
                if missing:
                    err_msg = f"Collector build did not produce expected archives: {', '.join(missing)}"
                    raise RuntimeError(err_msg)
                marker_path.touch()

    return CollectorArtifacts(
        dist_dir=dist_dir,
        postgres_zip=postgres_zip,
        mysql_zip=mysql_zip,
        oracle_zip=oracle_zip,
        sqlserver_zip=sqlserver_zip,
    )


@pytest.fixture(scope="session")
def collector_artifacts() -> CollectorArtifacts:
    """Return built collection script ZIP archives."""
    project_root = Path(__file__).resolve().parents[2]
    return build_collector_artifacts(project_root)


def _artifact_path(dist_dir: Path, key: str) -> Path:
    return dist_dir / ARTIFACT_NAMES[key]
