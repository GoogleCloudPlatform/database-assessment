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
"""Unit tests for the Oracle."""

from __future__ import annotations

from typing import TYPE_CHECKING

import pytest
from sqlalchemy import text

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncEngine


pytestmark = [
    pytest.mark.anyio,
    pytest.mark.oracle,
    pytest.mark.xdist_group("oracle"),
]


async def test_engine_connectivity(async_engine: AsyncEngine) -> None:
    async with async_engine.begin() as conn:
        await conn.execute(
            text("select 1 from dual"),
        )
