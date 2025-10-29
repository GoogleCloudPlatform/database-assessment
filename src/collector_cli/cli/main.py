"""Collector CLI for building and packaging database data extraction scripts."""

from __future__ import annotations

import rich_click as click
from rich.console import Console

console = Console()


@click.group(
    name="collector-cli",
    help="[bold #34A853]Database collection and data extraction tools[/bold #34A853]\n\n"
    "Generate, package, and execute scripts to collect database metadata, schema information, "
    "and performance metrics from various database systems.",
)
def cli() -> None:
    """Main CLI group."""


@cli.command(name="package-scripts", help="Build and package collection scripts into distributable ZIP archives")
@click.option(
    "--database",
    "-d",
    type=click.Choice(["mysql", "postgres", "oracle", "sqlserver"], case_sensitive=False),
    help="Specific database type to package (builds all if not specified)",
)
@click.option(
    "--output-dir",
    "-o",
    type=click.Path(exists=False, file_okay=False, dir_okay=True),
    default=None,
    help="Output directory for packaged collectors",
)
@click.option("--version", "-v", default=None, help="Version tag for the packages")
@click.option("--clean", "-c", is_flag=True, help="Clean build directory before packaging")
def package_scripts(database: str | None, output_dir: str | None, version: str | None, clean: bool) -> None:
    """Build and package collection scripts using Jinja2 templates."""
    from collector_cli.lib.settings import get_settings
    from collector_cli.packager import CollectorPackager

    settings = get_settings()
    if output_dir is None:
        output_dir = str(settings.collector.DEFAULT_OUTPUT_DIR)
    if version is None:
        version = settings.collector.DEFAULT_VERSION

    packager = CollectorPackager(output_dir=output_dir, version=version, clean=clean)

    if database:
        console.print(f"[green]✓[/green] Packaging {database} collector scripts")
        try:
            result = packager.package_collector(database)
            if "package_path" in result:
                console.print(f"[dim]Created: {result['package_path']}[/dim]")
            elif "error" in result:
                console.print(f"[bold red]Error: {result['error']}[/bold red]")
        except Exception as e:
            console.print(f"[bold red]An unexpected error occurred: {e}[/bold red]")
    else:
        console.print("[green]✓[/green] Packaging all collector scripts")
        results = packager.package_all_collectors()
        for db_type, result in results.items():
            if "package_path" in result:
                console.print(f"[dim]{db_type}: {result['package_path']}[/dim]")
            elif "error" in result:
                console.print(f"[bold red]Error packaging {db_type}: {result['error']}[/bold red]")

    console.print(f"[blue]Package(s) created in: {output_dir}[/blue]")
