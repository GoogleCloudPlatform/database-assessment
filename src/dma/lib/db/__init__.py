import aiosql

from dma.lib.db.adapters.asyncmy import AsyncMYAdapter
from dma.lib.db.adapters.asyncpg import AsyncPGAdapter
from dma.lib.db.adapters.oracledb import AsyncOracleDBAdapter

aiosql.register_adapter("asyncpg", AsyncPGAdapter)  # type: ignore[arg-type]
aiosql.register_adapter("asyncmy", AsyncMYAdapter)  # type: ignore[arg-type]
aiosql.register_adapter("async_oracledb", AsyncOracleDBAdapter)  # type: ignore[arg-type]
