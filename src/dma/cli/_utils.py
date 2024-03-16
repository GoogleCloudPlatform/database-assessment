from __future__ import annotations

from importlib.util import find_spec

from rich import get_console

__all__ = (
    "RICH_CLICK_INSTALLED",
    "console",
)

RICH_CLICK_INSTALLED = find_spec("rich_click") is not None
console = get_console()
console._width = 80
