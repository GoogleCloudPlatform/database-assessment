from __future__ import annotations

from typing import Literal

from sqlalchemy import URL
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine


def get_engine(
    db_type: Literal["mysql", "postgres", "mssql", "oracle"],
    username: str,
    password: str,
    hostname: str,
    port: int,
    database: str,
) -> AsyncEngine:
    if db_type == "postgres":
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
    if db_type == "mysql":
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
    if db_type == "mssql":
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
    if db_type == "oracle":
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
