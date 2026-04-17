# Copyright 2024 Google LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Collection services for database data extraction.

This module provides database-specific collection services that use SQLSpec
drivers for efficient data extraction with Arrow-native data transfer.
"""

from __future__ import annotations

from dma.collector.services.postgres import PostgresCollectionService

__all__ = ("PostgresCollectionService",)
