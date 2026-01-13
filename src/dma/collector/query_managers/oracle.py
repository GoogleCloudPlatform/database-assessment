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

from typing import TYPE_CHECKING, Any

import aiosql
from aiosql.adapters.generic import GenericAdapter

from dma.collector.query_managers.base import CollectionQueryManager
from dma.utils import module_to_os_path

if TYPE_CHECKING:
    from aiosql.queries import Queries

_root_path = module_to_os_path("dma")

aiosql.register_adapter("oracledb", GenericAdapter)


class OracleCollectionQueryManager(CollectionQueryManager):
    def __init__(
        self,
        connection: Any,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
        queries: Queries = aiosql.from_path(
            sql_path=f"{_root_path}/collector/sql/sources/oracle/",
            driver_adapter="oracledb",
            mandatory_parameters=False,
        ),
    ) -> None:
        super().__init__(
            connection=connection, queries=queries, execution_id=execution_id, source_id=source_id, manual_id=manual_id
        )
