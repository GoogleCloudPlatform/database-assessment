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

import aiosql

from dma.lib.db.adapters import AIOODBCAdapter, AsyncMYAdapter, AsyncOracleDBAdapter, AsyncPGAdapter

aiosql.register_adapter("asyncpg", AsyncPGAdapter)  # type: ignore[arg-type]
aiosql.register_adapter("asyncmy", AsyncMYAdapter)  # type: ignore[arg-type]
aiosql.register_adapter("async_oracledb", AsyncOracleDBAdapter)  # type: ignore[arg-type]
aiosql.register_adapter("aioodbc", AIOODBCAdapter)  # type: ignore[arg-type]
