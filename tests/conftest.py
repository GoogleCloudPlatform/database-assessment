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
