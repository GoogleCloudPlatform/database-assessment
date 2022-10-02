from aiosql.adapters.generic import GenericAdapter


class DuckDBAdapter(GenericAdapter):
    """Implements a duckdb backend for aiosql."""


class BigQueryAdapter(GenericAdapter):
    """Implements a Google BigQuery backend for aiosql."""
