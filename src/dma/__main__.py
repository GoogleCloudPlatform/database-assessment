"""Database Migration Assessment - Application Entrypoint"""

# SPDX-FileCopyrightText: 2023-present Cody Fincher <codyfincher@google.com>
#
# SPDX-License-Identifier: MIT
from __future__ import annotations

import sys
from pathlib import Path

current_path = Path(__file__).parent.parent.resolve()
sys.path.append(str(current_path))

from dma.cli.main import app

app()
