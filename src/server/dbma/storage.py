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
