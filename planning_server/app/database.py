"""Database setup — SQLAlchemy async with SQLite."""

from datetime import datetime, timezone

from sqlalchemy import Column, String, Integer, Float, Text, DateTime, Boolean, ForeignKey, Enum as SAEnum
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase, relationship

from planning_server.app import config


class Base(DeclarativeBase):
    pass


# --- Models ---

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    hashed_password = Column(String(128), nullable=False)
    role = Column(String(20), default="user")  # admin | user
    status = Column(String(20), default="pending")  # pending | approved | rejected
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    projects = relationship("Project", back_populates="owner")


class Project(Base):
    __tablename__ = "projects"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), nullable=False)
    description = Column(Text, default="")
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    status = Column(String(20), default="active")  # active | archived
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    owner = relationship("User", back_populates="projects")
    conversations = relationship("Conversation", back_populates="project", cascade="all, delete-orphan")
    generated_files = relationship("GeneratedFile", back_populates="project", cascade="all, delete-orphan")


class Conversation(Base):
    __tablename__ = "conversations"

    id = Column(Integer, primary_key=True, autoincrement=True)
    project_id = Column(Integer, ForeignKey("projects.id"), nullable=False)
    title = Column(String(200), default="")
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    project = relationship("Project", back_populates="conversations")
    messages = relationship("Message", back_populates="conversation", cascade="all, delete-orphan")


class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, autoincrement=True)
    conversation_id = Column(Integer, ForeignKey("conversations.id"), nullable=False)
    role = Column(String(20), nullable=False)  # user | assistant | system
    content = Column(Text, nullable=False)
    model_used = Column(String(50), default="")
    token_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    conversation = relationship("Conversation", back_populates="messages")


class GeneratedFile(Base):
    __tablename__ = "generated_files"

    id = Column(Integer, primary_key=True, autoincrement=True)
    project_id = Column(Integer, ForeignKey("projects.id"), nullable=False)
    file_type = Column(String(20), nullable=False)  # scad | stl | cpp | dart | urdf
    file_path = Column(String(500), nullable=False)
    version = Column(Integer, default=1)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    project = relationship("Project", back_populates="generated_files")


class SimulationJob(Base):
    __tablename__ = "simulation_jobs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    project_id = Column(Integer, ForeignKey("projects.id"), nullable=False)
    job_id = Column(String(50), unique=True, nullable=False)  # UUID
    status = Column(String(20), default="queued")
    simulation_type = Column(String(20), default="full")
    feedback_json = Column(Text, default="")
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    completed_at = Column(DateTime, nullable=True)


# --- Engine & Session ---

engine = create_async_engine(config.DATABASE_URL, echo=False)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def init_db():
    """Create all tables."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def get_db() -> AsyncSession:
    """Dependency injection for database sessions."""
    async with async_session() as session:
        yield session
