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

import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING

import pytest

from tools.lib.container import ContainerRuntime

if TYPE_CHECKING:
    from collections.abc import Sequence


@dataclass
class CollectorResult:
    exit_code: int
    stdout: str
    stderr: str
    output_dir: Path | None
    output_archive: Path | None
    error_log: Path | None
    execution_time: float


class ScriptExecutor:
    """Executes collection scripts inside database containers."""

    def __init__(self, runtime: ContainerRuntime) -> None:
        self.runtime = runtime

    def copy_to_container(self, container_name: str, local_path: Path, container_path: str) -> None:
        self.runtime.run_command(["cp", str(local_path), f"{container_name}:{container_path}"])

    def exec_in_container(
        self,
        container_name: str,
        command: Sequence[str],
        timeout: int | None = None,
        workdir: str | None = None,
    ) -> tuple[int, str, str]:
        args = ["exec"]
        if workdir:
            args.extend(["-w", workdir])
        args.append(container_name)
        args.extend(command)
        return self.runtime.run_command(args, timeout=timeout, check=False)

    def copy_from_container(self, container_name: str, container_path: str, local_path: Path) -> tuple[int, str, str]:
        return self.runtime.run_command(["cp", f"{container_name}:{container_path}", str(local_path)], check=False)

    def run_collector(
        self,
        container_name: str,
        zip_path: Path,
        db_type: str,
        connection_string: str,
        extra_args: Sequence[str] | None = None,
        timeout: int = 300,
    ) -> CollectorResult:
        container_work_dir = f"/tmp/collector-{int(time.time())}"
        script_name = "collect-data.sh"
        start_time = time.time()

        self.exec_in_container(container_name, ["mkdir", "-p", container_work_dir])

        container_zip = f"{container_work_dir}/{zip_path.name}"
        self.copy_to_container(container_name, zip_path, container_zip)

        self.exec_in_container(container_name, ["unzip", "-q", container_zip, "-d", container_work_dir])

        script_dir = f"{container_work_dir}/{db_type}"
        extra = " ".join(extra_args) if extra_args else ""
        command = [
            "bash",
            "-c",
            f"cd {script_dir} && ./{script_name} --connectionStr {connection_string} {extra}".strip(),
        ]

        exit_code, stdout, stderr = self.exec_in_container(
            container_name,
            command,
            timeout=timeout,
        )

        execution_time = time.time() - start_time

        output_dir = Path(tempfile.mkdtemp(prefix="dma-collector-output-"))
        copy_exit, _, _ = self.copy_from_container(container_name, f"{script_dir}/output/.", output_dir)
        if copy_exit != 0:
            output_dir = None

        output_archive = None
        error_log = None
        if output_dir and output_dir.exists():
            archives = list(output_dir.glob("*.zip")) + list(output_dir.glob("*.tar.gz"))
            output_archive = archives[0] if archives else None
            error_logs = list(output_dir.glob("*_errors.log"))
            error_log = error_logs[0] if error_logs else None

        return CollectorResult(
            exit_code=exit_code,
            stdout=stdout,
            stderr=stderr,
            output_dir=output_dir,
            output_archive=output_archive,
            error_log=error_log,
            execution_time=execution_time,
        )


@pytest.fixture(scope="session")
def script_executor() -> ScriptExecutor:
    return ScriptExecutor(ContainerRuntime())
