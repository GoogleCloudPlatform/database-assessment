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
