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
from __future__ import annotations

from typing import Final

RDS_MINOR_VERSION_SUPPORT_MAP: Final[dict[float, int]] = {}
DB_TYPE_MAP: Final[dict[float, str]] = {
    5.6: "MYSQL_5_6",
    5.7: "MYSQL_5_7",
    8.0: "MYSQL_8_0",
}
