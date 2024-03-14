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
        console.rule("executing collection queries...", align="left")
        results: dict[str, Any] = {}
        for script in self.collection_queries:
            console.print(f" [yellow]*[/] executing collection query {script}")
            script_result = await self.select(script, PKEY="test", DMA_SOURCE_ID="testing", DMA_MANUAL_ID=None)
            results[script] = script_result
        if not self.collection_queries:
            console.print(" [dim yellow]*[/] [dim]No collection queries for this database type. Skipping stage...[/]")
        return results

    async def execute_extended_collection_queries(self) -> dict[str, Any]:
        """Execute extended collection queries.

        Returns: None
        """
        console.rule("executing extended collection queries...", align="left")
        results: dict[str, Any] = {}
        for script in self.extended_collection_queries:
            console.print(f" [yellow]*[/] executing extended collection query {script}")
            script_result = await self.select(script, PKEY="test", DMA_SOURCE_ID="testing", DMA_MANUAL_ID=None)
            results.update({script: script_result})
            await self.select(script)
        if not self.extended_collection_queries:
            console.print(" [dim yellow]*[/] [dim]No extended collection queries for this database type. Skipping stage...[/]")
        return results


class CanonicalQueryManager(QueryManager):
    """Canonical Query Manager"""

    @property
    def transformation_queries(self) -> list[str]:
        """Get transformation scripts."""
        return sorted(
            [q for q in self.queries.available_queries if q.startswith("transformation") and not q.endswith("cursor")],
        )

    def execute_transformation_queries(self, *args: Any, **kwargs: Any) -> dict[str, Any]:
        """Execute pre-processing queries."""
        console.rule("executing transformation queries...", align="left")
        results: dict[str, Any] = {}
        for script in self.transformation_queries:
            console.print(f" [yellow]*[/] executing transformation query {script}")
            script_result = self.select(script, PKEY="test", DMA_SOURCE_ID="testing", DMA_MANUAL_ID=None)
            results[script] = script_result
        if not self.transformation_queries:
            console.print(" [dim yellow]*[/] [dim]No transformation queries for this database type. Skipping stage...[/]")
        return results

    @property
    def assessment_queries(self) -> list[str]:
        """Get load scripts."""
        return sorted(
            [q for q in self.queries.available_queries if q.startswith("assessment") and not q.endswith("cursor")],
        )

    def execute_assessment_queries(self, *args: Any, **kwargs: Any) -> dict[str, Any]:
        """Execute pre-processing queries."""
        console.rule("executing assessment queries...", align="left")
        results: dict[str, Any] = {}
        for script in self.assessment_queries:
            console.print(f" [yellow]*[/] executing assessment query {script}")
            script_result = self.select(script, PKEY="test", DMA_SOURCE_ID="testing", DMA_MANUAL_ID=None)
            results[script] = script_result
        if not self.assessment_queries:
            console.print(" [dim yellow]*[/] [dim]No assessment queries for this database type.  Skipping stage...[/]")
        return results
