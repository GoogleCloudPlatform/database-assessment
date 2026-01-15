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

from typing import Literal, TypeAlias

# Currently only PostgreSQL is supported. MySQL, MSSQL, and Oracle coming in future releases.
SupportedSources: TypeAlias = Literal["POSTGRES"]
PostgresVariants: TypeAlias = Literal["CLOUDSQL", "ALLOYDB"]
# Future database support placeholders
MySQLVariants: TypeAlias = Literal["CLOUDSQL"]
MSSQLVariants: TypeAlias = Literal["CLOUDSQL"]
OracleVariants: TypeAlias = Literal["BMS"]
SeverityLevels: TypeAlias = Literal["ACTION REQUIRED", "ERROR", "WARNING", "INFO", "PASS"]
