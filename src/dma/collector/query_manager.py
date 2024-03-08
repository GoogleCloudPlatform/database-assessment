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
from dma.lib.db.query_manager import QueryManager


class CollectionQueryManager(QueryManager):
    """Collection Query Manager"""

    @property
    def collection_queries(self) -> list[str]:
        """Get transformation scripts."""
        return sorted(
            [q for q in self.queries.available_queries if q.startswith("collection") and not q.endswith("cursor")],
        )

    @property
    def extended_collection_queries(self) -> list[str]:
        """Get load scripts."""
        return sorted(
            [
                q
                for q in self.queries.available_queries
                if q.startswith("extended-collection") and not q.endswith("cursor")
            ],
        )

    async def execute_collection_queries(self, *args: Any, **kwargs: Any) -> dict[str, Any]:
        """Execute pre-processing queries."""
        console.print("executing collection queries")
        results: dict[str, Any] = {}
        for script in self.collection_queries:
            console.print(f".. executing collection query {script}")
            script_result = await self.select(script, PKEY="test", DMA_SOURCE_ID="testing", DMA_MANUAL_ID=None)
            results.update({script: script_result})
        return results

    async def execute_extended_collection_queries(self) -> dict[str, Any]:
        """Execute extended collection queries.

        Returns: None
        """
        console.print("executing extended collection queries")
        results: dict[str, Any] = {}
        for script in self.extended_collection_queries:
            console.print(f".. executing extended collection query {script}")
            script_result = await self.select(script, PKEY="test", DMA_SOURCE_ID="testing", DMA_MANUAL_ID=None)
            results.update({script: script_result})
            await self.select(script)
        return results
