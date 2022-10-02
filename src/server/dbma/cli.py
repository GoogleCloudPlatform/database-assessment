import typer
from rich.console import Console
from rich.traceback import install as rich_tracebacks

__all__ = ["console", "app"]

TEXT_LOGO = """
[bold yellow]✨ Database Migration Advisor
"""


app = typer.Typer(no_args_is_help=True, name="Oracle Database Migration Advisor")


console = Console(markup=True, emoji=True, color_system="truecolor", stderr=False)
rich_tracebacks(console=console, suppress=("sqlalchemy", "aiosql", "google"))


@app.command(name="upload-collection")
def upload_collection(
    collection: str = typer.Option(None, "--collection", "-c", help="Path to collection zip to upload")
) -> None:
    """Upload a collection to Google"""
    console.log(collection)


@app.command(name="process-collection")
def process_collection(
    collection: str = typer.Option(None, "--collection", "-c", help="Path to collection zip to upload"),
) -> None:
    """Process a collection"""
    console.log(collection)
