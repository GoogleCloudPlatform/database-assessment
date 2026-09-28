"""Sphinx configuration for Database Migration Assessment documentation."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

from dma.__about__ import __version__

project = "Database Migration Assessment"
copyright = "2024, Google LLC"
author = "Google LLC"
version = __version__
release = __version__

extensions = [
    "sphinx.ext.autodoc",
    "sphinx.ext.napoleon",
    "sphinx.ext.viewcode",
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
