"""Click CLI commands for project management.

This module provides Click command groups for non-Oracle project management tasks:
- Project initialization
- Prerequisite installation
- Health checks and diagnostics
"""

from __future__ import annotations

__all__ = [
    "doctor_command",
    "init_command",
    "install_all_command",
    "install_gemini_cli_command",
    "install_group",
    "install_list_command",
    "install_mcp_toolbox_command",
    "install_sqlcl_command",
    "install_uv_command",
]

from tools.cli.doctor import doctor_command
from tools.cli.init import init_command
from tools.cli.install import (
    install_all_command,
    install_gemini_cli_command,
    install_group,
    install_list_command,
    install_mcp_toolbox_command,
    install_sqlcl_command,
    install_uv_command,
)
