"""Packaging module for the collector CLI."""

from __future__ import annotations

import shutil
import zipfile
from pathlib import Path
from typing import Any

from collector_cli.lib.settings import get_settings
from collector_cli.packaging import OracleScriptRenderer, SqlServerPackageBuilder, StandardScriptBuilder


class CollectorPackager:
    """Main class for building and packaging database collector scripts."""

    def __init__(
        self,
        output_dir: str | None = None,
        version: str | None = None,
        clean: bool = False,
    ) -> None:
        """Initialize the collector packager."""
        settings = get_settings()
        self.output_dir = Path(output_dir) if output_dir else settings.collector.DEFAULT_OUTPUT_DIR
        self.version = version or settings.collector.DEFAULT_VERSION
        self.clean = clean
        self.build_dir = self.output_dir / "build"
        self.template_path = settings.collector.TEMPLATES_DIR
        self.macros_path = self.template_path / "macros"

        self.output_dir.mkdir(parents=True, exist_ok=True)

        if self.clean and self.build_dir.exists():
            shutil.rmtree(self.build_dir)

        self.build_dir.mkdir(parents=True, exist_ok=True)

    def package_collector(self, database_type: str) -> dict[str, Any]:
        """Package a single database collector."""
        if database_type == "oracle":
            return self._build_oracle()
        if database_type == "sqlserver":
            return self._build_sqlserver()
        if database_type in {"postgres", "mysql"}:
            return self._build_standard(database_type)

        msg = f"Unsupported database type: {database_type}"
        raise ValueError(msg)

    def _build_oracle(self) -> dict[str, Any]:
        """Builds the Oracle collector package."""
        renderer = OracleScriptRenderer(
            template_path=self.template_path / "scripts" / "oracle",
            macros_path=self.macros_path,
        )
        # The entry script for Oracle is op_collect.sql.j2
        # We need to pass initial context, including version and output directory
        initial_context = {
            "version": self.version,
            "outputdir": str(self.build_dir / "oracle"),  # This will be defined in the SQL*Plus context
            "target": "script",
        }
        rendered_content = renderer.render("sql/op_collect.sql.j2", initial_context)

        # Oracle packaging is complex due to SQL*Plus pre-processor. The renderer returns the final script.
        # We need to write this script and then package it along with other necessary files.
        # For now, we'll just write the rendered content to a dummy file and zip it.
        collector_build_dir = self.build_dir / "oracle"
        collector_build_dir.mkdir(parents=True, exist_ok=True)
        (collector_build_dir / "collect-data.sh").write_text(rendered_content)

        # TODO: Copy other static files and SQL files as needed for Oracle
        # For now, just zip the rendered script
        package_path = self._create_zip_package(collector_build_dir, "oracle")

        return {"database_type": "oracle", "package_path": str(package_path)}

    def _build_sqlserver(self) -> dict[str, Any]:
        """Builds the SQL Server collector package."""
        builder = SqlServerPackageBuilder(
            template_path=self.template_path,
            macros_path=self.macros_path,
            build_dir=self.build_dir,
            output_dir=self.output_dir,
            version=self.version,
        )
        return builder.build_package()

    def _build_standard(self, database_type: str) -> dict[str, Any]:
        """Builds a standard shell-based collector package."""
        builder = StandardScriptBuilder(
            template_path=self.template_path,
            macros_path=self.macros_path,
            build_dir=self.build_dir,
            output_dir=self.output_dir,
            version=self.version,
            database_type=database_type,
        )
        return builder.build_package()

    def _create_zip_package(self, source_dir: Path, database_type: str) -> Path:
        """Create a ZIP package from the build directory."""
        zip_filename = f"db-migration-assessment-collection-scripts-{database_type}.zip"
        zip_path = self.output_dir / zip_filename

        if zip_path.exists():
            zip_path.unlink()

        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zipf:
            for file_path in source_dir.rglob("*"):
                arcname = file_path.relative_to(source_dir)
                zipf.write(file_path, arcname)

        return zip_path

    def package_all_collectors(self) -> dict[str, dict[str, Any]]:
        """Package all supported database collectors."""
        results = {}
        for db_type in ["oracle", "sqlserver", "postgres", "mysql"]:
            try:
                results[db_type] = self.package_collector(db_type)
            except Exception as e:
                results[db_type] = {"database_type": db_type, "error": str(e)}
        return results
