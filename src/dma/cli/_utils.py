from __future__ import annotations

from importlib.util import find_spec

from rich import get_console

RICH_CLICK_INSTALLED = find_spec("rich-click") is not None


__all__ = (
    "RICH_CLICK_INSTALLED",
    "console",
)


console = get_console()
