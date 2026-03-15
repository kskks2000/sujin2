from __future__ import annotations

from contextlib import contextmanager

from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool


class DatabaseManager:
    def __init__(self, dsn: str):
        self.pool = ConnectionPool(conninfo=dsn, min_size=1, max_size=8, open=False)

    def open(self) -> None:
        self.pool.open()

    def close(self) -> None:
        self.pool.close()

    @contextmanager
    def connection(self):
        with self.pool.connection() as conn:
            yield conn

    def fetch_all(self, query: str, params: tuple | dict | None = None):
        with self.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
            cur.execute(query, params)
            return cur.fetchall()

    def fetch_one(self, query: str, params: tuple | dict | None = None):
        with self.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
            cur.execute(query, params)
            return cur.fetchone()
