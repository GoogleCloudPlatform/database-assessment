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

from typing import Literal

from sqlalchemy import URL
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine


def get_engine(
    db_type: Literal["POSTGRES", "MYSQL", "ORACLE", "MSSQL"],
    username: str,
    password: str,
    hostname: str,
    port: int,
    database: str,
) -> AsyncEngine:
    if db_type == "POSTGRES":
        return create_async_engine(
            URL(
                drivername="postgresql+asyncpg",
                username=username,
                password=password,
                host=hostname,
                port=port,
                database=database,
                query={},  # type: ignore[arg-type]
            ),
        )
    if db_type == "MYSQL":
        return create_async_engine(
            URL(
                drivername="mysql+asyncmy",
                username=username,
                password=password,
                host=hostname,
                port=port,
                database=database,
                query={},  # type: ignore[arg-type]
            ),
        )
    if db_type == "MSSQL":
        return create_async_engine(
            URL(
                drivername="mssql+aioodbc",
                username=username,
                password=password,
                host=hostname,
                port=port,
                database=database,
                query={
                    "driver": "ODBC Driver 18 for SQL Server",
                    "encrypt": "no",
                    "TrustServerCertificate": "yes",
                    # NOTE: MARS_Connection is only needed for the concurrent async tests
                    # lack of this causes some tests to fail
                    # https://github.com/jolt-org/advanced-alchemy/actions/runs/6800623970/job/18493034767?pr=94
                    "MARS_Connection": "yes",
                },  # type: ignore[arg-type]
            ),
        )
    if db_type == "ORACLE":
        return create_async_engine(
            "oracle+oracledb://:@",
            thick_mode=False,
            connect_args={
                "user": username,
                "password": password,
                "host": hostname,
                "port": port,
                "service_name": database,
            },
        )
    msg = f"{db_type} is not a supported engine."  # type: ignore[unreachable]
    raise NotImplementedError(msg)
