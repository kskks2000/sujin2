from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router
from app.core.cache import CacheManager
from app.core.config import get_settings
from app.core.database import DatabaseManager

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.db = DatabaseManager(settings.database_url)
    app.state.db.open()

    app.state.cache = CacheManager(settings.redis_url)
    app.state.cache.open()
    try:
        yield
    finally:
        app.state.cache.close()
        app.state.db.close()


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    description="Sujin TMS API for orders, shipments, dispatch, and master data.",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.api_v1_prefix)


@app.get("/health", tags=["health"])
def healthcheck():
    return {"status": "ok", "service": settings.app_name}
