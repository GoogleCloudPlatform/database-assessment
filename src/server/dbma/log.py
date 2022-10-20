# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
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
