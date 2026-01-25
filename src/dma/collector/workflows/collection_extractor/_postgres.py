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
"""PostgreSQL-specific collection workflow utilities."""

from __future__ import annotations

from typing import TYPE_CHECKING

from rich.table import Table

if TYPE_CHECKING:
    from rich.console import Console
    from sqlspec.adapters.duckdb import DuckDBDriver

    from dma.collector.query_managers.base import CanonicalQueryManager


def print_summary_postgres(
    console: Console,
    driver: "DuckDBDriver",
    manager: CanonicalQueryManager,
) -> None:
    """Print Summary of the Migration Readiness Assessment.

    Args:
        console: Rich console for output.
        driver: SQLSpec DuckDB driver.
        manager: Canonical query manager.
    """
    summary_table = Table(show_edge=False, width=80)
    print_database_details(console=console, driver=driver, manager=manager)
    console.print(summary_table)


def print_database_details(
    console: Console,
    driver: "DuckDBDriver",
    manager: CanonicalQueryManager,
) -> None:
    """Print database details from calculated metrics.

    Args:
        console: Rich console for output.
        driver: SQLSpec DuckDB driver.
        manager: Canonical query manager.
    """
    calculated_metrics = driver.select(
        "select metric_category, metric_name, metric_value from collection_postgres_calculated_metrics"
    )
    count_table = Table(show_edge=False, width=80)
    count_table.add_column("Variable Category", justify="right", style="green")
    count_table.add_column("Variable", justify="right", style="green")
    count_table.add_column("Value", justify="right", style="green")

    for row in calculated_metrics:
        count_table.add_row(str(row["metric_category"]), str(row["metric_name"]), str(row["metric_value"]))
    console.print(count_table)
