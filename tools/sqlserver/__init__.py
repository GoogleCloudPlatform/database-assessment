"""SQL Server database management tools."""

from tools.sqlserver.cli import connect_group, database_group, health_command
from tools.sqlserver.connection import ConnectionConfig, ConnectionTester, DeploymentMode
from tools.sqlserver.database import DatabaseConfig, SQLServerDatabase
from tools.sqlserver.health import HealthChecker, HealthStatus, SystemHealth

__all__ = [
    # CLI commands
    "connect_group",
    "database_group",
    "health_command",
    # Core classes
    "ConnectionConfig",
    "ConnectionTester",
    "DatabaseConfig",
    "DeploymentMode",
    "HealthChecker",
    "HealthStatus",
    "SQLServerDatabase",
    "SystemHealth",
]
