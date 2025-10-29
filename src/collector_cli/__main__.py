"""DMA CLI main entry point."""

from collector_cli.cli.main import cli as collector_cli


def main() -> None:
    """Entry point for the DMA Collector CLI."""
    collector_cli()


if __name__ == "__main__":
    main()
