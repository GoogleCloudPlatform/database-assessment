from __future__ import annotations

from rich import get_console

__all__ = ("console",)

console = get_console()
console._width = 80
