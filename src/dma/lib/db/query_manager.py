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

import contextlib
import faulthandler
from typing import TYPE_CHECKING, Any, TypeVar

from typing_extensions import Self

from dma.lib.exceptions import ApplicationError

faulthandler.enable()
if TYPE_CHECKING:
    from collections.abc import Iterator

    from aiosql.queries import Queries

QueryManagerT = TypeVar("QueryManagerT", bound="QueryManager")


class QueryManager:
    """Stores the queries for a version of the collection."""

    queries: Queries
    connection: Any

    def __init__(self, connection: Any, queries: Queries) -> None:
        self.connection = connection
        self.queries = queries

    def available_queries(self, prefix: str | None = None) -> list[str]:
        """Get available queries optionally filtered to queries starting with prefix."""
        if prefix is None:
            return sorted(
                [q for q in self.queries.available_queries if not q.endswith("cursor")],
            )
        return sorted(
            [q for q in self.queries.available_queries if q.startswith(prefix) and not q.endswith("cursor")],
        )

    @classmethod
    @contextlib.contextmanager
    def from_connection(
        cls,
        queries: Queries,
        connection: Any,
    ) -> Iterator[Self]:
        """Context manager that returns instance of query manager object."""
        yield cls(connection=connection, queries=queries)

    def select(self, method: str, **binds: Any) -> list[dict[str, Any]]:
        data = self.fn(method)(conn=self.connection, **binds)
        return [dict(row) for row in data]

    def select_one(self, method: str, **binds: Any) -> dict[str, Any]:
        data = self.fn(method)(conn=self.connection, **binds)
        return dict(data)

    def select_one_value(self, method: str, **binds: Any) -> Any:
        return self.fn(method)(conn=self.connection, **binds)

    def insert_update_delete(self, method: str, **binds: Any) -> None:
        return self.fn(method)(conn=self.connection, **binds)

    def insert_update_delete_many(self, method: str, **binds: Any) -> Any | None:
        return self.fn(method)(conn=self.connection, **binds)

    def insert_returning(self, method: str, **binds: Any) -> Any | None:
        return self.fn(method)(conn=self.connection, **binds)

    def execute(self, method: str, **binds: Any) -> Any:
        return self.fn(method)(conn=self.connection, **binds)

    def fn(self, method: str) -> Any:
        try:
            return getattr(self.queries, method)
        except AttributeError as exc:
            msg = "%s was not found"
            raise ApplicationError(msg, method) from exc
