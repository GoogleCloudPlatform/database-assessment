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
"""Root pytest configuration and shared session hooks for DMA."""

from __future__ import annotations

import os
import uuid
from pathlib import Path
from typing import Any

import pytest

pytestmark = pytest.mark.anyio
here = Path(__file__).parent
root_path = here.parent
pytest_plugins = [
    "tests.database",
    "tests.lib.collector_build",
    "tests.lib.script_executor",
]


def pytest_configure(config: pytest.Config) -> None:
    """Propagate a single test-run UID across xdist workers."""
    if hasattr(config, "workerinput"):
        worker_input: dict[str, Any] = config.workerinput
        if "dma_test_run_uid" in worker_input:
            os.environ["DMA_TEST_RUN_UID"] = str(worker_input["dma_test_run_uid"])
    elif "DMA_TEST_RUN_UID" not in os.environ:
        os.environ["DMA_TEST_RUN_UID"] = str(uuid.uuid4())


def pytest_configure_node(node: Any) -> None:
    """Pass the master test-run UID to each xdist worker node."""
    node.workerinput["dma_test_run_uid"] = os.environ["DMA_TEST_RUN_UID"]


@pytest.fixture(scope="session")
def anyio_backend() -> str:
    """Return the default AnyIO backend for async tests."""
    return "asyncio"
