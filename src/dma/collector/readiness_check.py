from __future__ import annotations

from typing import TYPE_CHECKING

import duckdb
import polars as pl
from rich.table import Table

if TYPE_CHECKING:
    import duckdb
    from rich.console import Console


class AssessmentWorkflow:
    """A collection of tasks that interact with DuckDB"""

    def __init__(self, local_db: duckdb.DuckDBPyConnection, console: Console) -> None:
        """Initialize a Readiness Check."""
        self.local_db = local_db
        self.console = console

    def import_to_table(self, data: dict[str, list[dict]]) -> None:
        for table_name, table_data in data.items():
            if len(table_data) > 0:
                self.local_db.register(table_name, pl.from_dicts(table_data, infer_schema_length=10000))


class ReadinessCheck(AssessmentWorkflow):
    def print_summary(self) -> None:
        """Print Summary of the Migration Readiness Assessment."""
        calculated_metrics = self.local_db.sql(
            """
                select variable_category, variable_name, variable_value
                from collection_mysql_config
            """,
        ).fetchall()
        count_table = Table(show_edge=False)
        count_table.add_column("Variable Category", justify="right", style="green")
        count_table.add_column("Variable", justify="right", style="green")
        count_table.add_column("Value", justify="right", style="green")

        for row in calculated_metrics:
            count_table.add_row(*[str(col) for col in row])
        self.console.print(count_table)
