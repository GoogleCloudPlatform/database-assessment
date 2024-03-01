from __future__ import annotations

import platform
from importlib.util import find_spec
from pathlib import Path


def module_to_os_path(dotted_path: str = "app") -> Path:
    """Find Module to OS Path.

    Return path to the base directory of the project or the module
    specified by `dotted_path`.
    """
    src = find_spec(dotted_path)
    if src is None:
        msg = "Couldn't find the path for %s"
        raise TypeError(msg, dotted_path)
    path_separator = "\\" if platform.system() == "Windows" else "/"
    return Path(str(src.origin).removesuffix(f"{path_separator}__init__.py"))
