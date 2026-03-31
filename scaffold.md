Here's the complete FastAPI skeleton for your SaaS:

**main.py**
```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import sentry_sdk
from contextlib import asynccontextmanager
from config import settings
from routers import health

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    if settings.SENTRY_DSN:
        sentry_sdk.init(
            dsn=settings.SENTRY_DSN,
            traces_sample_rate=1.0,
            profiles_sample_rate=1.0,
        )
    yield
    # Shutdown

app = FastAPI(lifespan=lifespan, title="NDA Generator SaaS")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
```

**config.py**
```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    ENV: str = "development"
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/nda_saas"
    REDIS_URL: str = "redis://localhost:6379/0"
    SENTRY_DSN: str | None = None
    CORS_ORIGINS: list[str] = ["*"]
    
    class Config:
        env_file = ".env"

settings = Settings()
```

**models/base.py**
```python
from sqlalchemy.ext.asyncio import AsyncAttrs
from sqlalchemy.orm import DeclarativeBase

class Base(AsyncAttrs, DeclarativeBase):
    pass
```

**models/nda.py**
```python
from sqlalchemy import Column, String, Text, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
from models.base import Base

class NDAModel(Base):
    __tablename__ = "ndas"
    
    id = Column(UUID(as_uuid=True), primary_key=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
```

**routers/health.py**
```python
from fastapi import APIRouter
from fastapi.responses import JSONResponse

router = APIRouter(prefix="/health")

@router.get("")
async def health_check():
    return JSONResponse({"status": "ok"})
```

**alembic.ini**
```ini
[alembic]
script_location = alembic
sqlalchemy.url = postgresql+asyncpg://postgres:postgres@localhost:5432/nda_saas

[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console
qualname =

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
```

**alembic/env.py**
```python
from logging.config import fileConfig
from sqlalchemy import pool
from alembic import context
from models.base import Base
import asyncio
import os

config = context.config
fileConfig(config.config_file_name)
target_metadata = Base.metadata

def run_migrations_offline():
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()

def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()

async def run_async_migrations():
    connectable = pool.AsyncAdaptedQueuePool(
        creator=lambda: context.config.attributes["connection"],
        pool_size=1,
        max_overflow=0,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

def run_migrations_online():
    connectable = config.attributes.get("connection", None)
    if connectable is None:
        asyncio.run(run_async_migrations())
    else:
        do_run_migrations(connectable)

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

**requirements.txt**
```
fastapi==0.109.1
uvicorn==0.27.0
python-dotenv==1.0.0
pydantic-settings==2.2.1
sqlalchemy==2.0.25
asyncpg==0.29.0
alembic==1.13.1
redis==5.0.1
sentry-sdk==1.39.1
```

**Dockerfile**
```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
```

**docker-compose.yml**
```yaml
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: nda_saas
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      - ENV=development
      - DATABASE_URL=postgresql+asyncpg://postgres:postgres@db:5432/nda_saas
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis

  worker:
    build: .
    command: ["python", "-m", "worker"]
    environment:
      - ENV=development
      - DATABASE_URL=postgresql+asyncpg://postgres:postgres@db:5432/nda_saas
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis

volumes:
  redis_data:
  postgres_data:
```