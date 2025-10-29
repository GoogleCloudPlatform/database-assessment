"""Standard script builder for PostgreSQL and MySQL collectors."""

import shutil
import zipfile
from pathlib import Path
from typing import Any

from jinja2 import Environment, FileSystemLoader


class StandardScriptBuilder:
    """Builds standard shell-based collector packages for PostgreSQL and MySQL."""

    def __init__(
        self,
        template_path: Path,
        macros_path: Path,
        build_dir: Path,
        output_dir: Path,
        version: str,
        database_type: str,
    ) -> None:
        """Initializes the builder with paths, version, and database type."""
        self.template_path = template_path
        self.macros_path = macros_path
        self.build_dir = build_dir
        self.output_dir = output_dir
        self.version = version
        self.database_type = database_type

        self.env = Environment(
            loader=FileSystemLoader([str(template_path), str(macros_path)]),
            autoescape=False,
            trim_blocks=True,
            lstrip_blocks=True,
        )

    def build_package(self) -> dict[str, Any]:
        """Renders all standard templates and creates a zip package."""
        collector_build_dir = self.build_dir / self.database_type

        if collector_build_dir.exists():
            shutil.rmtree(collector_build_dir)
        collector_build_dir.mkdir(parents=True)

        context = {
            "version": self.version,
            "database_type": self.database_type,
            "target": "script",  # Standard scripts are always for the script target
            # TODO: Add other necessary context variables
        }

        # Render all templates into the temporary build directory
        for template_name in self.env.list_templates(extensions=[".j2"]):
            if template_name.startswith(f"scripts/{self.database_type}/") or template_name.startswith(
                f"sql/src/sources/{self.database_type}/"
            ):
                template = self.env.get_template(template_name)
                rendered_content = template.render(context)

                # Determine output path, removing the .j2 extension
                relative_output_path = Path(template_name).relative_to(self.template_path)
                output_filename = collector_build_dir / relative_output_path.with_suffix("")

                output_filename.parent.mkdir(parents=True, exist_ok=True)
                output_filename.write_text(rendered_content)

                # Make shell scripts executable
                if output_filename.suffix == ".sh":
                    output_filename.chmod(0o755)

        # Create output directory within the package
        (collector_build_dir / "output").mkdir(exist_ok=True)

        # Create ZIP package
        package_path = self._create_zip_package(collector_build_dir, self.database_type)

        return {
            "database_type": self.database_type,
            "package_path": str(package_path),
            "build_dir": str(collector_build_dir),
        }

    def _create_zip_package(self, source_dir: Path, database_type: str) -> Path:
        """Create a ZIP package from the build directory."""
        zip_filename = f"db-migration-assessment-collection-scripts-{database_type}.zip"
        zip_path = self.output_dir / zip_filename

        if zip_path.exists():
            zip_path.unlink()

        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zipf:
            for file_path in source_dir.rglob("*"):
                arcname = file_path.relative_to(source_dir)
                if file_path.is_file():
                    zipf.write(file_path, arcname)
                elif file_path.is_dir():
                    zipf.writestr(str(arcname) + "/", "")

        return zip_path
