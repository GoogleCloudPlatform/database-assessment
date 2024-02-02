# SPDX-FileCopyrightText: 2023-present Cody Fincher <codyfincher@google.com>
#
# SPDX-License-Identifier: MIT
from __future__ import annotations

import sys
from pathlib import Path


def run_cli() -> None:
    """Application Entrypoint."""
    current_path = Path(__file__).parent.parent.resolve()
    sys.path.append(str(current_path))
    try:
        from litestar.__main__ import run_cli as run_litestar_cli

    except ImportError as exc:
        print(  # noqa: T201
            "Could not load required libraries.  ",
            "Please check your installation and make sure you activated any necessary virtual environment",
        )
        print(exc)  # noqa: T201
        sys.exit(1)
    run_litestar_cli()


if __name__ == "__main__":
    run_cli()
