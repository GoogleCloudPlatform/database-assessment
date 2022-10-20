import logging
from typing import Any, Literal, Optional

from fsspec.implementations.local import LocalFileSystem
from gcsfs import GCSFileSystem

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
        if self.backend == "file":
            self.fs = LocalFileSystem(auto_mkdir=True)
        elif self.backend == "gcs":
            self.fs = GCSFileSystem(
                project=settings.google_project_id, requests_timeout=4, token=settings.google_application_credentials
            )


engine = StorageBucket(backend=settings.storage_backend, backend_options=settings.storage_backend_options)
