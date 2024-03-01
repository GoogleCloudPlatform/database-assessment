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

from typing import Any

from dma.cli._utils import console
from dma.lib.query_manager import QueryManager


class CollectionQueryManager(QueryManager):
    """Collection Query Manager"""

    @property
    def collection_queries(self) -> list[str]:
        """Get transformation scripts."""
        return sorted(
            [q for q in self.queries.available_queries if q.startswith("collection")],
        )

    @property
    def extended_collection_queries(self) -> list[str]:
        """Get load scripts."""
        return sorted(
            [q for q in self.queries.available_queries if q.startswith("extended-collection")],
        )

    def execute_collection_queries(self, *args: Any, **kwargs: Any) -> None:
        """Execute pre-processing queries."""
        console.print("executing collection queries")
        for script in self.collection_queries:
            console.print(f".. executing collection query {script}")
            getattr(self, script)()

    def execute_extended_collection_queries(self) -> None:
        """Execute extended collection queries.

        Returns: None
        """
        console.print("executing extended collection queries")

        for script in self.extended_collection_queries:
            fn = getattr(self, script)
            console.print(f".. executing extended collection query {script}")

            fn()
