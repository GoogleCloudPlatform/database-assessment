"""Oracle SQL*Plus-aware Jinja2 renderer."""

import re
from pathlib import Path
from typing import Any

from jinja2 import Environment, FileSystemLoader


class OracleScriptRenderer:
    """Renders Oracle SQL*Plus scripts, emulating DEFINE and @include behavior."""

    def __init__(self, template_path: Path, macros_path: Path) -> None:
        """Initialize the renderer."""
        self.env = Environment(
            loader=FileSystemLoader([str(template_path), str(template_path / "sql"), str(macros_path)]),
            autoescape=False,  # We're generating shell scripts, not HTML  # noqa: S701
            trim_blocks=True,
            lstrip_blocks=True,
        )
        self.context: dict[str, Any] = {}
        self.define_pattern = re.compile(r"DEFINE\s+(\w+)\s*=\s*'?([^'\s]+)'?", re.IGNORECASE)
        self.substitute_pattern = re.compile(r"&(\w+)")
        self.include_pattern = re.compile(r"^@\s*(.*)", re.MULTILINE)
        self.rendered_scripts = set()

    def render(self, entry_script_name: str, initial_context: dict[str, Any]) -> str:
        """Render the entry script and all its includes."""
        self.context = initial_context.copy()
        self.rendered_scripts.clear()
        return self._render_recursive(entry_script_name)

    def _process_defines_and_substitutions(self, content: str) -> str:
        """Process DEFINE statements and substitute &variables."""
        # Find all DEFINE statements and update context
        for match in self.define_pattern.finditer(content):
            var, value = match.groups()
            self.context[var] = value

        # Substitute all &variables
        def substitute_variable(match: re.Match[str]) -> str:
            var_name = match.group(1)
            # If the variable is in our context, substitute it. Otherwise, leave it.
            return self.context.get(var_name, f"&{var_name}")

        return self.substitute_pattern.sub(substitute_variable, content)

    def _render_recursive(self, script_name: str) -> str:
        """Render a script and its includes recursively."""
        if script_name in self.rendered_scripts:
            return ""  # Avoid infinite loops
        self.rendered_scripts.add(script_name)

        template = self.env.get_template(script_name)
        # First, render Jinja templates
        processed_content = template.render(self.context)

        # Second, handle SQL*Plus DEFINE and & substitutions
        processed_content = self._process_defines_and_substitutions(processed_content)

        # Third, handle SQL*Plus @ includes
        def render_include(match: re.Match[str]) -> str:
            include_name = match.group(1).strip().lstrip("@")

            # If the include path contains a SQL*Plus variable, leave it for runtime
            if "&" in include_name:
                return match.group(0)

            # Render the include name itself in case it's a Jinja variable
            resolved_include_name = self.env.from_string(include_name).render(self.context)
            return self._render_recursive(resolved_include_name)

        return self.include_pattern.sub(render_include, processed_content)
