from pathlib import Path
from typing import Any, Optional, Type, Union

from packaging.version import LegacyVersion, Version

from dbma import db, log
from dbma.config import BaseSchema

__all__ = ["CollectionConfig", "BaseCollection", "VersionProfile"]

logger = log.get_logger()

ScriptVersionType = Union[Version, LegacyVersion]


class BaseCollection(BaseSchema):
    """Base Schema for file Collection"""

    _file_mapper: dict[str, str] = {}

    def load(self, db: db.SQLManager, delimiter: str = "|") -> None:
        """Returns first values in a list or None"""
        for file_type, file_name in self.dict(exclude_unset=True, exclude_none=True).items():
            has_load_fn = hasattr(db, f"load_{file_type}")
            if not has_load_fn:
                logger.warning("... [bold yellow] Could not find a load procedure for %s.", file_type)
            if file_name.stat().st_size > 0:
                fn = getattr(db, f"load_{file_type}")
                rows_loaded = fn(str(file_name.absolute()), delimiter)
                logger.info("... %s  [green bold]SUCCESS[/] [%s rows(s)]", file_type, rows_loaded)
            else:
                logger.info("... %s  [dim bold]SKIPPED[/] [empty file]", file_type)

    def process(self, db: db.SQLManager, *args: Any, **kwargs: Any) -> Any:
        """Returns first values in a list or None"""
        fn = getattr(db, "process_collection", None)
        if not fn:
            raise ValueError("Could not find the specified load function")
        return fn(*args, **kwargs)

    @classmethod
    def from_file_list(cls, files: list[Path]) -> "BaseCollection":
        """Returns first values in a list or None"""
        return cls.parse_obj({key: cls._match_path(value, files) for key, value in cls._file_mapper.items()})

    @classmethod
    def _match_path(cls, match_string: str, list_of_paths: list[Path]) -> Optional[Path]:
        for value in list_of_paths:
            if value.name.startswith(match_string):
                return value
        return None


class CollectionConfig(BaseSchema):
    delimiter: str = "|"
    collection_schema: Type[BaseCollection]
    sql_files_path: str


class VersionProfile(BaseSchema):
    min_version: ScriptVersionType
    max_version: ScriptVersionType
    config: CollectionConfig


class CollectionArchive(BaseSchema):
    config: CollectionConfig
    files: BaseCollection
