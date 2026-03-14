"""
Async SQLAlchemy engine and session factory for PostgreSQL.
Supports Neon serverless Postgres (requires sslmode=require).
"""

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from config import get_settings

_engine = None
_session_factory = None


def get_engine():
    global _engine
    if _engine is None:
        settings = get_settings()
        url = settings.DATABASE_URL
        # Normalize URL to use asyncpg driver regardless of what the env var provides
        if url.startswith("postgresql://"):
            url = url.replace("postgresql://", "postgresql+asyncpg://", 1)

        # Neon serverless Postgres: needs SSL and conservative pool sizes
        is_neon = "neon.tech" in url or "neon" in url
        connect_args = {"ssl": "require"} if is_neon else {}

        _engine = create_async_engine(
            url,
            pool_size=3 if is_neon else 5,
            max_overflow=2 if is_neon else 5,
            pool_pre_ping=True,
            pool_recycle=300,
            echo=settings.APP_ENV == "development",
            connect_args=connect_args,
        )
    return _engine


def get_session_factory() -> async_sessionmaker[AsyncSession]:
    global _session_factory
    if _session_factory is None:
        _session_factory = async_sessionmaker(
            get_engine(), class_=AsyncSession, expire_on_commit=False
        )
    return _session_factory


async def get_db() -> AsyncSession:
    """FastAPI dependency that yields an async session and auto-commits/rollbacks."""
    factory = get_session_factory()
    async with factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def init_db() -> None:
    """Create all tables. Called once at startup."""
    from db.models import Base
    engine = get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def close_db() -> None:
    global _engine, _session_factory
    if _engine:
        await _engine.dispose()
        _engine = None
        _session_factory = None
