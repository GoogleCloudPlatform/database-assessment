import sys
from pathlib import Path

sys.path.insert(0, str(Path("../src").resolve()))

project = "Database Migration Assessment"
copyright = "2024, Google LLC"
author = "Google LLC"

extensions = [
    "sphinx.ext.autodoc",
    "sphinx.ext.intersphinx",
    "sphinx.ext.napoleon",
    "sphinx.ext.viewcode",
    "myst_parser",
    "sphinx_copybutton",
    "sphinx_design",
    "sphinx_immaterial",
]

html_theme = "sphinx_immaterial"
html_static_path = ["_static"]
html_css_files = ["custom.css"]

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
        "toc.sticky",
        "search.share",
        "content.code.annotate",
        "content.code.copy",
    ],
}
