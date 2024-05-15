from __future__ import annotations

from typing import Literal, TypeAlias

SupportedSources: TypeAlias = Literal["POSTGRES", "MYSQL", "ORACLE", "MSSQL"]
PostgresVariants: TypeAlias = Literal["CLOUDSQL", "ALLOYDB"]
MySQLVariants: TypeAlias = Literal["CLOUDSQL"]
MSSQLVariants: TypeAlias = Literal["CLOUDSQL"]
OracleVariants: TypeAlias = Literal["BMS"]
SeverityLevels: TypeAlias = Literal["ERROR", "WARNING", "INFO", "PASS"]
