import os
import logging
import time
from contextlib import asynccontextmanager
from datetime import datetime

import redis.asyncio as redis
from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from sqlalchemy import Column, Integer, String, DateTime, text
from sqlalchemy.sql import func
from pydantic import BaseModel

# ── Logging ────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)

logger = logging.getLogger("app")

# ── Settings ───────────────────────────────────────────────────────────────────
DATABASE_URL = os.environ["DATABASE_URL"]

REDIS_URL = os.environ.get(
    "REDIS_URL",
    "redis://redis:6379/0"
)

APP_ENV = os.environ.get(
    "APP_ENV",
    "production"
)

ALLOWED_ORIGINS = os.environ.get(
    "ALLOWED_ORIGINS",
    "*"
).split(",")

# ── Database Setup ─────────────────────────────────────────────────────────────
engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    pool_pre_ping=True
)

AsyncSession_ = sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False
)

class Base(DeclarativeBase):
    pass

class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    content = Column(String, nullable=False)

    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now()
    )

async def get_db():
    async with AsyncSession_() as session:
        yield session

# ── Redis Setup ────────────────────────────────────────────────────────────────
redis_client = None

# ── Application Lifespan ──────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    global redis_client

    logger.info("Connecting to PostgreSQL...")
    logger.info("Connecting to Redis at %s", REDIS_URL)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    redis_client = redis.from_url(
        REDIS_URL,
        decode_responses=True
    )

    logger.info("Application started — env=%s", APP_ENV)

    yield

    await redis_client.aclose()
    await engine.dispose()

    logger.info("Application stopped")

# ── FastAPI App ────────────────────────────────────────────────────────────────
app = FastAPI(
    title="DevOps Demo API",
    version="1.0.0",
    lifespan=lifespan
)

# ── Middleware ────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()

    response = await call_next(request)

    process_time = time.time() - start_time

    logger.info(
        "%s %s completed_in=%.2fs status=%s",
        request.method,
        request.url.path,
        process_time,
        response.status_code,
    )

    return response

# ── Pydantic Schemas ───────────────────────────────────────────────────────────
class MessageCreate(BaseModel):
    content: str

class MessageOut(BaseModel):
    id: int
    content: str
    created_at: datetime

    class Config:
        from_attributes = True

# ── Health & Readiness Endpoints ──────────────────────────────────────────────
@app.get("/health", tags=["ops"])
async def health_check():
    checks = {
        "status": "ok",
        "timestamp": time.time(),
        "env": APP_ENV,
    }

    # PostgreSQL Check
    try:
        async with AsyncSession_() as session:
            await session.execute(text("SELECT 1"))

        checks["postgres"] = "ok"

    except Exception as exc:
        checks["postgres"] = f"error: {exc}"
        checks["status"] = "degraded"

    # Redis Check
    try:
        await redis_client.ping()

        checks["redis"] = "ok"

    except Exception as exc:
        checks["redis"] = f"error: {exc}"
        checks["status"] = "degraded"

    if checks["status"] == "degraded":
        raise HTTPException(
            status_code=503,
            detail=checks
        )

    return checks

@app.get("/ready", tags=["ops"])
async def readiness_check():
    return {
        "status": "ready"
    }

# ── Root Endpoint ─────────────────────────────────────────────────────────────
@app.get("/", tags=["root"])
async def root():
    return {
        "message": "DevOps Demo API is running",
        "docs": "/docs"
    }

# ── Message Endpoints ─────────────────────────────────────────────────────────
@app.post(
    "/messages",
    response_model=MessageOut,
    tags=["messages"]
)
async def create_message(
    body: MessageCreate,
    db: AsyncSession = Depends(get_db)
):
    msg = Message(content=body.content)

    db.add(msg)

    await db.commit()
    await db.refresh(msg)

    # Cache in Redis for 60 seconds
    await redis_client.setex(
        f"msg:{msg.id}",
        60,
        msg.content
    )

    logger.info("Created message id=%d", msg.id)

    return msg

@app.get(
    "/messages/{msg_id}",
    response_model=MessageOut,
    tags=["messages"]
)
async def get_message(
    msg_id: int,
    db: AsyncSession = Depends(get_db)
):
    # Redis Cache Check
    cached = await redis_client.get(f"msg:{msg_id}")

    if cached:
        logger.info("Cache hit for msg:%d", msg_id)

        return MessageOut(
            id=msg_id,
            content=cached,
            created_at=datetime.utcnow()
        )

    # Database Lookup
    result = await db.get(Message, msg_id)

    if not result:
        raise HTTPException(
            status_code=404,
            detail="Message not found"
        )

    return result