from logging import config as _logging_config
from logging import getLogger
from typing import TYPE_CHECKING, Optional

from dbma.config import settings

if TYPE_CHECKING:
    from logging import Logger


__all__ = ["config", "get_logger"]
config = {
    "version": 1,
    "root": {"level": settings.log_level, "handlers": ["console"]},
    "handlers": {
        "console": {
            "class": "rich.logging.RichHandler",
            "markup": True,
            "rich_tracebacks": True,
            "omit_repeated_times": False,
        },
    },
    "formatters": {
        "standard": {"format": "%(message)s"},
    },
    "loggers": {
        "sqlalchemy": {
            "propagate": False,
            "level": "WARNING",
            "handlers": ["console"],
        },
    },
}
"""
Pre-configured log config for application.
"""


def get_logger(name: Optional[str] = None) -> "Logger":
    """Returns a configured logger for the given name

    Args:
        name (str, optional): _description_. Defaults to "dbma".

    Returns:
        Logger: A configured logger instance
    """
    return getLogger(name)


_logging_config.dictConfig(config)
