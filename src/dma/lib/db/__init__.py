import aiosql

from dma.lib.db.adapters import AIOODBCAdapter, AsyncMYAdapter, AsyncOracleDBAdapter, AsyncPGAdapter

aiosql.register_adapter("asyncpg", AsyncPGAdapter)  # type: ignore[arg-type]
aiosql.register_adapter("asyncmy", AsyncMYAdapter)  # type: ignore[arg-type]
aiosql.register_adapter("async_oracledb", AsyncOracleDBAdapter)  # type: ignore[arg-type]
aiosql.register_adapter("aioodbc", AIOODBCAdapter)  # type: ignore[arg-type]
