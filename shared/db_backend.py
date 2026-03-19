"""Database abstraction — local (SQLAlchemy) or cloud (Firestore).

Usage:
    from shared.db_backend import get_db_backend, DatabaseBackend

    db = get_db_backend()  # auto-detects local vs cloud via ENVIRONMENT

    user = await db.get_user_by_username("admin")
    projects = await db.list_projects_by_owner("1")
"""

import logging
import os
import uuid
from abc import ABC, abstractmethod
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger(__name__)


class DatabaseBackend(ABC):
    """Abstract database interface used by all routers."""

    # --- User operations ---

    @abstractmethod
    async def get_user_by_id(self, user_id: str) -> dict | None:
        ...

    @abstractmethod
    async def get_user_by_username(self, username: str) -> dict | None:
        ...

    @abstractmethod
    async def create_user(self, username: str, hashed_password: str,
                          role: str = "user", status: str = "pending") -> dict:
        ...

    @abstractmethod
    async def list_users(self, status: str | None = None) -> list[dict]:
        ...

    @abstractmethod
    async def update_user(self, user_id: str, data: dict) -> dict:
        ...

    # --- Project operations ---

    @abstractmethod
    async def get_project(self, project_id: str) -> dict | None:
        ...

    @abstractmethod
    async def list_projects_by_owner(self, owner_id: str) -> list[dict]:
        ...

    @abstractmethod
    async def create_project(self, name: str, description: str,
                             owner_id: str) -> dict:
        ...

    @abstractmethod
    async def update_project(self, project_id: str, data: dict) -> dict:
        ...

    @abstractmethod
    async def delete_project(self, project_id: str) -> None:
        ...

    @abstractmethod
    async def list_all_projects(self, limit: int = 100) -> list[dict]:
        ...


class SQLAlchemyDB(DatabaseBackend):
    """SQLAlchemy async wrapper — returns dicts for interface consistency."""

    def __init__(self, session_factory):
        self._session_factory = session_factory

    def _user_to_dict(self, user) -> dict:
        return {
            "id": str(user.id),
            "username": user.username,
            "hashed_password": user.hashed_password,
            "role": user.role,
            "status": user.status,
            "created_at": user.created_at.isoformat() if user.created_at else "",
        }

    def _project_to_dict(self, project) -> dict:
        return {
            "id": str(project.id),
            "name": project.name,
            "description": project.description or "",
            "owner_id": str(project.owner_id),
            "status": project.status,
            "created_at": project.created_at.isoformat() if project.created_at else "",
            "updated_at": project.updated_at.isoformat() if project.updated_at else "",
        }

    async def get_user_by_id(self, user_id: str) -> dict | None:
        from sqlalchemy import select
        from planning_server.app.database import User
        async with self._session_factory() as db:
            result = await db.execute(select(User).where(User.id == int(user_id)))
            user = result.scalar_one_or_none()
            return self._user_to_dict(user) if user else None

    async def get_user_by_username(self, username: str) -> dict | None:
        from sqlalchemy import select
        from planning_server.app.database import User
        async with self._session_factory() as db:
            result = await db.execute(select(User).where(User.username == username))
            user = result.scalar_one_or_none()
            return self._user_to_dict(user) if user else None

    async def create_user(self, username: str, hashed_password: str,
                          role: str = "user", status: str = "pending") -> dict:
        from planning_server.app.database import User
        async with self._session_factory() as db:
            user = User(
                username=username,
                hashed_password=hashed_password,
                role=role,
                status=status,
            )
            db.add(user)
            await db.commit()
            await db.refresh(user)
            return self._user_to_dict(user)

    async def list_users(self, status: str | None = None) -> list[dict]:
        from sqlalchemy import select
        from planning_server.app.database import User
        async with self._session_factory() as db:
            q = select(User)
            if status:
                q = q.where(User.status == status)
            result = await db.execute(q)
            return [self._user_to_dict(u) for u in result.scalars().all()]

    async def update_user(self, user_id: str, data: dict) -> dict:
        from sqlalchemy import select
        from planning_server.app.database import User
        async with self._session_factory() as db:
            result = await db.execute(select(User).where(User.id == int(user_id)))
            user = result.scalar_one_or_none()
            if not user:
                raise ValueError(f"User {user_id} not found")
            for k, v in data.items():
                if hasattr(user, k):
                    setattr(user, k, v)
            await db.commit()
            await db.refresh(user)
            return self._user_to_dict(user)

    async def get_project(self, project_id: str) -> dict | None:
        from sqlalchemy import select
        from planning_server.app.database import Project
        async with self._session_factory() as db:
            result = await db.execute(select(Project).where(Project.id == int(project_id)))
            project = result.scalar_one_or_none()
            return self._project_to_dict(project) if project else None

    async def list_projects_by_owner(self, owner_id: str) -> list[dict]:
        from sqlalchemy import select
        from planning_server.app.database import Project
        async with self._session_factory() as db:
            result = await db.execute(
                select(Project).where(Project.owner_id == int(owner_id))
            )
            return [self._project_to_dict(p) for p in result.scalars().all()]

    async def create_project(self, name: str, description: str,
                             owner_id: str) -> dict:
        from planning_server.app.database import Project
        async with self._session_factory() as db:
            project = Project(
                name=name,
                description=description,
                owner_id=int(owner_id),
            )
            db.add(project)
            await db.commit()
            await db.refresh(project)
            return self._project_to_dict(project)

    async def update_project(self, project_id: str, data: dict) -> dict:
        from sqlalchemy import select
        from planning_server.app.database import Project
        async with self._session_factory() as db:
            result = await db.execute(select(Project).where(Project.id == int(project_id)))
            project = result.scalar_one_or_none()
            if not project:
                raise ValueError(f"Project {project_id} not found")
            for k, v in data.items():
                if hasattr(project, k):
                    setattr(project, k, v)
            await db.commit()
            await db.refresh(project)
            return self._project_to_dict(project)

    async def delete_project(self, project_id: str) -> None:
        from sqlalchemy import select
        from planning_server.app.database import Project
        async with self._session_factory() as db:
            result = await db.execute(select(Project).where(Project.id == int(project_id)))
            project = result.scalar_one_or_none()
            if project:
                await db.delete(project)
                await db.commit()

    async def list_all_projects(self, limit: int = 100) -> list[dict]:
        from sqlalchemy import select
        from planning_server.app.database import Project
        async with self._session_factory() as db:
            result = await db.execute(
                select(Project).order_by(Project.created_at.desc()).limit(limit)
            )
            return [self._project_to_dict(p) for p in result.scalars().all()]


class CloudFirestoreDB(DatabaseBackend):
    """Firestore-backed database for cloud deployment."""

    def __init__(self, project: str | None = None):
        from google.cloud import firestore
        self.client = firestore.Client(project=project)
        logger.info(f"[Firestore] Connected (project={project})")

    def _query(self, collection: str, field: str, op: str, value: Any,
               limit: int = 100) -> list[dict]:
        docs = (
            self.client.collection(collection)
            .where(field, op, value)
            .limit(limit)
            .stream()
        )
        results = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            results.append(data)
        return results

    async def get_user_by_id(self, user_id: str) -> dict | None:
        ref = self.client.collection("users").document(str(user_id))
        doc = ref.get()
        if doc.exists:
            data = doc.to_dict()
            data["id"] = doc.id
            return data
        return None

    async def get_user_by_username(self, username: str) -> dict | None:
        results = self._query("users", "username", "==", username, limit=1)
        return results[0] if results else None

    async def create_user(self, username: str, hashed_password: str,
                          role: str = "user", status: str = "pending") -> dict:
        doc_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc).isoformat()
        data = {
            "username": username,
            "hashed_password": hashed_password,
            "role": role,
            "status": status,
            "created_at": now,
        }
        self.client.collection("users").document(doc_id).set(data)
        data["id"] = doc_id
        return data

    async def list_users(self, status: str | None = None) -> list[dict]:
        if status:
            return self._query("users", "status", "==", status)
        docs = self.client.collection("users").stream()
        results = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            results.append(data)
        return results

    async def update_user(self, user_id: str, data: dict) -> dict:
        data["updated_at"] = datetime.now(timezone.utc).isoformat()
        self.client.collection("users").document(str(user_id)).update(data)
        # Fetch updated doc
        return await self.get_user_by_id(user_id)

    async def get_project(self, project_id: str) -> dict | None:
        ref = self.client.collection("projects").document(str(project_id))
        doc = ref.get()
        if doc.exists:
            data = doc.to_dict()
            data["id"] = doc.id
            return data
        return None

    async def list_projects_by_owner(self, owner_id: str) -> list[dict]:
        return self._query("projects", "owner_id", "==", str(owner_id))

    async def create_project(self, name: str, description: str,
                             owner_id: str) -> dict:
        doc_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc).isoformat()
        data = {
            "name": name,
            "description": description,
            "owner_id": str(owner_id),
            "status": "active",
            "created_at": now,
            "updated_at": now,
        }
        self.client.collection("projects").document(doc_id).set(data)
        data["id"] = doc_id
        return data

    async def update_project(self, project_id: str, data: dict) -> dict:
        data["updated_at"] = datetime.now(timezone.utc).isoformat()
        self.client.collection("projects").document(str(project_id)).update(data)
        return await self.get_project(project_id)

    async def delete_project(self, project_id: str) -> None:
        self.client.collection("projects").document(str(project_id)).delete()

    async def list_all_projects(self, limit: int = 100) -> list[dict]:
        docs = (
            self.client.collection("projects")
            .order_by("created_at", direction="DESCENDING")
            .limit(limit)
            .stream()
        )
        results = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            results.append(data)
        return results


# --- Singleton ---

_db: DatabaseBackend | None = None


def get_db_backend() -> DatabaseBackend:
    """Get the database backend (auto-detects local vs cloud via ENVIRONMENT)."""
    global _db
    if _db is not None:
        return _db

    env = os.getenv("ENVIRONMENT", "local")
    if env == "cloud":
        project = os.getenv("GCP_PROJECT", "")
        _db = CloudFirestoreDB(project or None)
        logger.info("[DB] Using Firestore (cloud mode)")
    else:
        from planning_server.app.database import async_session
        _db = SQLAlchemyDB(async_session)
        logger.info("[DB] Using SQLAlchemy (local mode)")

    return _db


async def init_db_backend():
    """Initialize the database (creates tables for local, no-op for cloud)."""
    env = os.getenv("ENVIRONMENT", "local")
    if env != "cloud":
        from planning_server.app.database import init_db
        await init_db()
