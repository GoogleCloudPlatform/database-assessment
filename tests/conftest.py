# SPDX-FileCopyrightText: 2023-present Cody Fincher <codyfincher@google.com>
#
# SPDX-License-Identifier: MIT
"""Dummy conftest.py for `DMA`.

If you don't know what this is for, just leave it empty.
Read more about conftest.py under:
- https://docs.pytest.org/en/stable/fixture.html
- https://docs.pytest.org/en/stable/writing_plugins.html
"""

from __future__ import annotations

from pathlib import Path

import pytest

pytestmark = pytest.mark.anyio
here = Path(__file__).parent
root_path = here.parent
pytest_plugins = [
    "pytest_databases.docker",
    "pytest_databases.docker.postgres",
    "pytest_databases.docker.mariadb",
    "pytest_databases.docker.mysql",
    "pytest_databases.docker.oracle",
    "pytest_databases.docker.mssql",
]


@pytest.fixture(scope="session")
def compose_project_name() -> str:
    return "dma-test"


@pytest.fixture(scope="session")
def anyio_backend() -> str:
    return "asyncio"
