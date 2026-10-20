"""Sphinx configuration for Database Migration Assessment documentation."""

from __future__ import annotations

import re
from pathlib import Path

_pyproject_text = (Path(__file__).resolve().parent.parent / "pyproject.toml").read_text(encoding="utf-8")
_version_match = re.search(r'^version\s*=\s*"([^"]+)"', _pyproject_text, re.MULTILINE)
__version__ = _version_match.group(1) if _version_match else "0.0.0"

project = "Database Migration Assessment"
copyright = "2024, Google LLC"
author = "Google LLC"
version = __version__
release = __version__

extensions = [
    "myst_parser",
    "sphinx_design",
    "sphinx_immaterial",
]

html_theme = "sphinx_immaterial"
html_static_path = ["_static"]
html_css_files = ["custom.css"]

suppress_warnings = ["ref.param"]

myst_enable_extensions = [
    "colon_fence",
    "attrs_block",
    "deflist",
]
myst_heading_anchors = 3

html_theme_options = {
    "icon": {
        "repo": "fontawesome/brands/github",
        "logo": "material/database",
    },
    "repo_url": "https://github.com/GoogleCloudPlatform/database-assessment",
    "repo_name": "database-assessment",
    "palette": [
        {
            "media": "(prefers-color-scheme: light)",
            "scheme": "default",
            "primary": "light-green",
            "accent": "light-blue",
            "toggle": {
                "icon": "material/lightbulb",
                "name": "Switch to dark mode",
            },
        },
        {
            "media": "(prefers-color-scheme: dark)",
            "scheme": "slate",
            "primary": "light-green",
            "accent": "light-blue",
            "toggle": {
                "icon": "material/lightbulb-outline",
                "name": "Switch to light mode",
            },
        },
    ],
    "features": [
        "navigation.tabs",
        "navigation.sections",
        "navigation.top",
        "search.share",
        "content.code.annotate",
        "content.code.copy",
    ],
}
