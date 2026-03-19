"""Firestore database abstraction — drop-in replacement for SQLAlchemy ORM.

In cloud mode, uses Firestore Native. In local mode, uses SQLite via SQLAlchemy.
All routers use `get_db()` dependency which returns a `Database` interface.

Collections:
    users/{user_id}           -> User document
    projects/{project_id}     -> Project document
    conversations/{conv_id}   -> Conversation document
    messages/{msg_id}         -> Message document
    generated_files/{file_id} -> GeneratedFile document
    simulation_jobs/{job_id}  -> SimulationJob document
"""

import logging
import os
import uuid
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger(__name__)


class FirestoreDB:
    """Firestore-backed database with dict-style document access."""

    def __init__(self, project: str | None = None):
        from google.cloud import firestore
        self.client = firestore.Client(project=project)
        logger.info(f"[Firestore] Connected (project={project})")

    # --- Generic CRUD ---

    async def get(self, collection: str, doc_id: str) -> dict | None:
        ref = self.client.collection(collection).document(str(doc_id))
        doc = ref.get()
        if doc.exists:
            data = doc.to_dict()
            data["id"] = doc.id
            return data
        return None

    async def get_all(self, collection: str, limit: int = 100) -> list[dict]:
        docs = self.client.collection(collection).limit(limit).stream()
        results = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            results.append(data)
        return results

    async def query(self, collection: str, field: str, op: str, value: Any, limit: int = 100) -> list[dict]:
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

    async def create(self, collection: str, data: dict, doc_id: str | None = None) -> dict:
        doc_id = doc_id or str(uuid.uuid4())
        now = datetime.now(timezone.utc).isoformat()
        data.setdefault("created_at", now)
        data.setdefault("updated_at", now)
        self.client.collection(collection).document(doc_id).set(data)
        data["id"] = doc_id
        return data

    async def update(self, collection: str, doc_id: str, data: dict) -> dict:
        data["updated_at"] = datetime.now(timezone.utc).isoformat()
        self.client.collection(collection).document(str(doc_id)).update(data)
        data["id"] = doc_id
        return data

    async def delete(self, collection: str, doc_id: str) -> None:
        self.client.collection(collection).document(str(doc_id)).delete()

    async def count(self, collection: str) -> int:
        # Firestore count aggregation
        agg = self.client.collection(collection).count()
        results = agg.get()
        return results[0][0].value if results else 0

    # --- User-specific ---

    async def get_user_by_username(self, username: str) -> dict | None:
        results = await self.query("users", "username", "==", username, limit=1)
        return results[0] if results else None

    async def create_user(self, username: str, hashed_password: str, is_admin: bool = False, is_approved: bool = False) -> dict:
        return await self.create("users", {
            "username": username,
            "hashed_password": hashed_password,
            "is_admin": is_admin,
            "is_approved": is_approved,
        })

    # --- Project-specific ---

    async def get_projects_by_owner(self, owner_id: str, limit: int = 100) -> list[dict]:
        return await self.query("projects", "owner_id", "==", owner_id, limit=limit)

    async def create_project(self, name: str, description: str, owner_id: str) -> dict:
        return await self.create("projects", {
            "name": name,
            "description": description,
            "owner_id": owner_id,
            "status": "active",
        })


# --- Singleton ---

_db: FirestoreDB | None = None


def get_firestore_db() -> FirestoreDB:
    """Get Firestore database instance."""
    global _db
    if _db is None:
        project = os.getenv("GCP_PROJECT", "")
        _db = FirestoreDB(project or None)
    return _db
