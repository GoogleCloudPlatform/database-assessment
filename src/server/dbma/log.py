from logging import config as _logging_config

from dbma.config import settings

__all__ = ["config"]
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
_logging_config.dictConfig(config)
