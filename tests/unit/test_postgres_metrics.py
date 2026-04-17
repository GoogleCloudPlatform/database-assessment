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

from pathlib import Path


def test_is_rds_metric_present() -> None:
    sql_path = (
        Path(__file__).parents[2]
        / "src"
        / "dma"
        / "collector"
        / "sql"
        / "sources"
        / "postgres"
        / "collection-calculated_metrics.sql"
    )
    sql = sql_path.read_text(encoding="utf-8")
    assert "IS_RDS" in sql
    assert "rdsadmin" in sql
