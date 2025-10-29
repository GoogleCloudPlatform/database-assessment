"""Configuration management for the collector CLI."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

# Default paths
BASE_DIR = Path(__file__).parent.parent  # Points to collector_cli/ directory
TEMPLATES_DIR = BASE_DIR / "templates"


@dataclass
class CollectorSettings:
    """Database collector configuration."""

    # Template and SQL directories
    TEMPLATES_DIR: Path = field(default=TEMPLATES_DIR)

    # Default output settings
    DEFAULT_OUTPUT_DIR: Path = field(default=Path("./dist"))
    DEFAULT_VERSION: str = field(default="latest")

    # Packaging settings
    PACKAGE_NAME_TEMPLATE: str = field(default="db-migration-assessment-collection-scripts-{db_type}.zip")

    # Supported database types
    SUPPORTED_DB_TYPES: list[str] = field(default_factory=lambda: ["postgres", "mysql", "oracle", "sqlserver"])


@dataclass
class Settings:
    """Main settings container."""

    collector: CollectorSettings = field(default_factory=CollectorSettings)

    def ensure_directories(self) -> None:
        """Ensure required directories exist."""
        self.collector.DEFAULT_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def get_settings() -> Settings:
    """Get application settings."""
    return Settings()
