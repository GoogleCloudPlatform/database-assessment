from __future__ import annotations

import asyncio
import json
import os
import re
import subprocess
import sys
import timeit
from contextlib import asynccontextmanager
from pathlib import Path
from typing import TYPE_CHECKING, Any

import asyncpg
import pytest
from filelock import FileLock

if TYPE_CHECKING:
    from collections.abc import AsyncGenerator, Awaitable, Callable


here = Path(__file__).parent


async def wait_until_responsive(
    check: Callable[..., Awaitable],
    timeout: float,
    pause: float,
    **kwargs: Any,
) -> None:
    """Wait until a service is responsive.

    Args:
        check: Coroutine, return truthy value when waiting should stop.
        timeout: Maximum seconds to wait.
        pause: Seconds to wait between calls to `check`.
        **kwargs: Given as kwargs to `check`.
    """
    ref = timeit.default_timer()
    now = ref
    while (now - ref) < timeout:  # sourcery skip
        if await check(**kwargs):
            return
        await asyncio.sleep(pause)
        now = timeit.default_timer()

    msg = "Timeout reached while waiting on service!"
    raise RuntimeError(msg)


class DockerServiceRegistry:
    def __init__(self, tmp_path: Path, use_legacy_compose: bool = False) -> None:
        self._use_legacy_compose = use_legacy_compose
        if os.environ.get("DOCKER_USE_COMPOSE") != "true" or os.environ.get("GITHUB_ACTIONS") == "true":
            self._use_legacy_compose = True
        self._tmp_path = tmp_path
        self.docker_ip = self._get_docker_ip()
        self._base_command = ["docker-compose"] if self._use_legacy_compose else ["docker", "compose"]
        self._base_command.extend(
            [
                "--file=tests/docker-compose.yml",
                "--project-name=dma_pytest",
            ],
        )

    @staticmethod
    def _load_worker_list(worker_path: Path) -> list[str]:
        """Reads the worker id list from a file"""
        return json.loads(worker_path.read_text())["workers"]  # type: ignore

    @staticmethod
    def _write_worker_list(worker_path: Path, workers: list[str]) -> None:
        """Writes the worker id list to a file"""
        worker_path.write_text(json.dumps({"workers": workers}))

    def _get_docker_ip(self) -> str:
        docker_host = os.environ.get("DOCKER_HOST", "").strip()
        if not docker_host or docker_host.startswith("unix://"):
            return "127.0.0.1"

        if match := re.match(r"^tcp://(.+?):\d+$", docker_host):
            return match[1]

        msg = f'Invalid value for DOCKER_HOST: "{docker_host}".'
        raise ValueError(msg)

    @asynccontextmanager
    async def run_with_lock(
        self,
        name: str,
        *,
        check: Callable[..., Awaitable],
        timeout: float = 30,
        pause: float = 0.1,
        **kwargs: Any,
    ) -> AsyncGenerator[None, None]:
        service_name = Path(self._tmp_path / f"docker-compose-{name}")
        service_lock = Path(self._tmp_path / f"docker-compose-{name}.lock")
        worker_id: str = kwargs.pop("worker_id", "master")

        with FileLock(str(service_lock)):
            _start: bool = False
            if service_name.is_file():
                # a process has already started minio then register our worker id
                worker_list = self._load_worker_list(service_name)
                if len(worker_list) == 0:
                    # all other processes have finished and this one is late to the party but it can restart the list
                    _start = True
                worker_list.append(worker_id)
                self._write_worker_list(service_name, worker_list)
            else:
                # This is the first process so it must create the worker list file
                self._write_worker_list(service_name, [worker_id])
                _start = True
            if _start:
                await self.start(name=name, check=check, timeout=timeout, pause=pause, **kwargs)
            yield
        # process is finished so it should teardown minio if it is the last process
        with FileLock(str(service_lock)):
            workers = self._load_worker_list(service_name)
            workers.remove(worker_id)
            self._write_worker_list(service_name, workers)
            if len(workers) == 0:
                # it seems like we are the last worker so we can quit minio
                self.down()

    def run_command(self, *args: str) -> None:
        if sys.platform == "darwin":
            subprocess.call([*self._base_command, *args], shell=True)  # noqa: S602
        else:
            subprocess.run([*self._base_command, *args], check=True, capture_output=True)

    async def start(
        self,
        name: str,
        *,
        check: Callable[..., Awaitable],
        timeout: float = 30,
        pause: float = 0.1,
        **kwargs: Any,
    ) -> None:
        run_command = ["up", "-d", name]
        if not self._use_legacy_compose:
            run_command.append("--wait")
        self.run_command(*run_command)
        await wait_until_responsive(
            check=check,
            timeout=timeout,
            pause=pause,
            host=self.docker_ip,
            **kwargs,
        )

    def stop(self, name: str) -> None:
        pass

    def down(self) -> None:
        self.run_command("down", "-t", "5")


async def postgres_responsive(host: str) -> bool:
    try:
        conn = await asyncpg.connect(
            host=host,
            port=5423,
            user="postgres",
            database="postgres",
            password="super-secret",  # noqa: S106
        )
    except Exception:  # noqa: BLE001
        return False

    try:
        return (await conn.fetchrow("SELECT 1"))[0] == 1  # type: ignore
    finally:
        await conn.close()


@pytest.fixture(scope="session", autouse=True)
def docker_services(tmp_path_factory: pytest.TempPathFactory) -> DockerServiceRegistry:
    if sys.platform not in ("linux", "darwin") or os.environ.get("SKIP_DOCKER_TESTS"):
        pytest.skip("Docker not available on this platform")
    tmp_path: Path = tmp_path_factory.getbasetemp().parent
    return DockerServiceRegistry(tmp_path=tmp_path)


@pytest.fixture(scope="session")
def docker_ip(docker_services: DockerServiceRegistry) -> str:
    return docker_services.docker_ip


@pytest.fixture(scope="session")
def docker_compose_file() -> Path:
    """Load docker compose file.

    Returns:
        Path to the docker-compose file for end-to-end test environment.
    """
    return here / "docker-compose.yml"


@pytest.fixture(scope="session", autouse=True)
async def postgres_service(docker_services: DockerServiceRegistry) -> None:
    async with docker_services.run_with_lock("postgres", check=postgres_responsive):
        yield
