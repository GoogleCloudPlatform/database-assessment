# Copyright 2022 Google LLC
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
from __future__ import annotations

import contextlib
import faulthandler
from typing import TYPE_CHECKING, Any, TypeVar

from dma.lib.exceptions import ApplicationError

faulthandler.enable()
if TYPE_CHECKING:
    from collections.abc import AsyncIterator

    from aiosql.queries import Queries

QueryManagerT = TypeVar("QueryManagerT", bound="QueryManager")


class QueryManager:
    """Stores the queries for a version of the collection."""

    queries: Queries
    connection: Any

    def __init__(self, connection: Any, queries: Queries) -> None:
        self.connection = connection
        self.queries = queries

    @classmethod
    @contextlib.asynccontextmanager
    async def from_connection(
        cls: type[QueryManagerT],
        queries: Queries,
        connection: Any,
    ) -> AsyncIterator[QueryManagerT]:
        """Context manager that returns instance of query manager object.

        Returns:
            The service object instance.
        """
        yield cls(connection=connection, queries=queries)

    async def select(self, method: str, **binds: Any) -> list[dict[str, Any]]:
        data = await self.fn(method)(conn=self.connection, **binds)
        return [dict(row) for row in data]

    async def select_one(self, method: str, **binds: Any) -> dict[str, Any]:
        data = await self.fn(method)(conn=self.connection, **binds)
        return dict(data)

    async def select_one_value(self, method: str, **binds: Any) -> Any:
        return await self.fn(method)(conn=self.connection, **binds)

    async def insert_update_delete(self, method: str, **binds: Any) -> None:
        return await self.fn(method)(conn=self.connection, **binds)

    async def insert_update_delete_many(self, method: str, **binds: Any) -> Any | None:
        return await self.fn(method)(conn=self.connection, **binds)

    async def insert_returning(self, method: str, **binds: Any) -> Any | None:
        return await self.fn(method)(conn=self.connection, **binds)

    async def execute(self, method: str, **binds: Any) -> Any:
        return await self.fn(method)(conn=self.connection, **binds)

    def fn(self, method: str) -> Any:
        try:
            return getattr(self.queries, method)
        except AttributeError as exc:
            msg = "%s was not found"
            raise ApplicationError(msg, method) from exc
