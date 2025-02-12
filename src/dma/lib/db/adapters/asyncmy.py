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

from contextlib import asynccontextmanager

import asyncmy


class AsyncMYAdapter:
    is_aio_driver = True

    def process_sql(self, _query_name, _op_type, sql):
        """Pass through function because the ``asyncmy`` driver can already handle the
        ``:var_name`` format used by aiosql and doesn't need any additional processing.

        Args:
            _query_name (str): The name of the sql query.
            _op_type (SQLOperationType): The type of SQL operation performed by the query.
            sql: The sql as written before processing.

        Returns:
        - str: Original SQL text unchanged.
        """
        return sql

    async def select(self, conn, query_name, sql, parameters, record_class=None):
        async with self.select_cursor(conn, query_name, sql, parameters) as cur:
            await cur.execute(sql)
            results = await cur.fetchall()
            if record_class is not None:
                column_names = [c[0] for c in cur.description]
                results = [record_class(**dict(zip(column_names, row))) for row in results]
        return results

    async def select_one(self, conn, query_name, sql, parameters, record_class=None):
        async with self.select_cursor(conn, query_name, sql, parameters) as cur:
            await cur.execute(sql)
            result = await cur.fetchone()
            if result is not None and record_class is not None:
                column_names = [c[0] for c in cur.description]
                result = record_class(**dict(zip(column_names, result)))
        return result

    async def select_value(self, conn, query_name, sql, parameters):
        async with self.select_cursor(conn, query_name, sql, parameters) as cur:
            await cur.execute(sql)
            result = await cur.fetchone()
        if isinstance(result, dict):
            return result[next(iter(result))] if result else None
        return result[0] if result else None

    @asynccontextmanager
    async def select_cursor(self, conn, _query_name, sql, parameters):
        async with conn.cursor(cursor=asyncmy.cursors.DictCursor) as cur:
            yield cur

    async def insert_returning(self, conn, query_name, sql, parameters):
        async with self.select_cursor(conn, query_name, sql, parameters) as cur:
            await cur.execute(sql)
            return cur.lastrowid

    async def insert_update_delete(self, conn, query_name, sql, parameters):
        async with self.select_cursor(conn, query_name, sql, parameters) as cur:
            await cur.execute(sql)
            return cur.rowcount

    async def insert_update_delete_many(self, conn, query_name, sql, parameters):
        async with self.select_cursor(conn, query_name, sql, parameters) as cur:
            await cur.executemany(sql, parameters)

    async def execute_script(self, conn, query_name, sql, parameters):
        async with self.select_cursor(conn, query_name, sql, parameters) as cur:
            await cur.execute(sql)
        return "DONE"
