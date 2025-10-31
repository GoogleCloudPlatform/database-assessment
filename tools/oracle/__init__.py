"""Oracle deployment and management tools.

This package provides comprehensive Oracle database deployment and management:
- Local Oracle 23 Free container management (uses shared tools.lib.container)
- Remote database connectivity
- Autonomous Database wallet configuration
- SQLcl installation
- Health checking and monitoring
- Connection testing
- Click CLI command groups
"""

from __future__ import annotations

__all__ = [
    # Business logic classes
    "ConnectionConfig",
    "ConnectionTester",
    "DatabaseConfig",
    "DeploymentMode",
    "HealthChecker",
    "HealthStatus",
    "OracleDatabase",
    "SQLclConfig",
    "SQLclInstaller",
    "SystemHealth",
    "WalletConfig",
    "WalletConfigurator",
    "WalletInfo",
    # CLI command groups
    "connect_group",
    "database_group",
    "sqlcl_group",
    "status_command",
    "wallet_group",
]

# Import CLI command groups
from tools.oracle.cli import (
    connect_group,
    database_group,
    sqlcl_group,
    status_command,
    wallet_group,
)
from tools.oracle.connection import ConnectionConfig, ConnectionTester, DeploymentMode
from tools.oracle.database import DatabaseConfig, OracleDatabase
from tools.oracle.health import HealthChecker, HealthStatus, SystemHealth
from tools.oracle.sqlcl_installer import SQLclConfig, SQLclInstaller
from tools.oracle.wallet import WalletConfig, WalletConfigurator, WalletInfo
