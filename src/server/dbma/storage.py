import logging
from typing import Any, Literal, Optional, Union

import fsspec
import gcsfs  # pylance: reportMissingImports=false # pylint: disable=[unused-import]

from dbma.config import settings

logger = logging.getLogger()
DEFAULT_OPTIONS: dict[str, Any] = {}


class StorageBucket:
    """Object Storage Interface."""

    def __init__(
        self, backend: Literal["file", "gcs"] = "file", backend_options: Optional[dict[str, Any]] = None
    ) -> None:
        """Storage Bucket."""
        self.backend = backend
        self.backend_options = backend_options or {}
        self.fs: Union[gcsfs.GCSFileSystem, fsspec.implementations.dirfs.DirFileSystem] = fsspec.filesystem(
            backend, **backend_options
        )


engine = StorageBucket(backend=settings.storage_backend, backend_options=settings.storage_backend_options)
