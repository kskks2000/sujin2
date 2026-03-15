from __future__ import annotations

import redis


class CacheManager:
    def __init__(self, url: str):
        self.url = url
        self.client: redis.Redis | None = None

    def open(self) -> None:
        self.client = redis.Redis.from_url(self.url, decode_responses=True)

    def close(self) -> None:
        if self.client is not None:
            self.client.close()

    def get(self, key: str):
        if self.client is None:
            return None
        try:
            return self.client.get(key)
        except redis.RedisError:
            return None

    def set(self, key: str, value: str, ex: int | None = None) -> None:
        if self.client is None:
            return
        try:
            self.client.set(key, value, ex=ex)
        except redis.RedisError:
            return

    def delete(self, key: str) -> None:
        if self.client is None:
            return
        try:
            self.client.delete(key)
        except redis.RedisError:
            return
