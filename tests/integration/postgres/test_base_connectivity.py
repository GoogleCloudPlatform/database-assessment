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
"""Unit tests for the Postgres Connectivity."""

from __future__ import annotations

from typing import TYPE_CHECKING

import pytest
from sqlalchemy import text

if TYPE_CHECKING:
    from sqlalchemy import Engine


pytestmark = [
    pytest.mark.anyio,
    pytest.mark.postgres,
    pytest.mark.xdist_group("postgres"),
]


def test_engine_connectivity(sync_engine: Engine) -> None:
    with sync_engine.begin() as conn:
        result = conn.execute(
            text("select 1"),
        )
        assert result.scalar() == 1
