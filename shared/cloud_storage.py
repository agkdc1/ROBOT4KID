"""Cloud storage abstraction — local filesystem or GCS.

Usage:
    from shared.cloud_storage import get_storage
    storage = get_storage()  # auto-detects local vs cloud

    # Write
    storage.write("projects/15/robot_spec.json", json_bytes)

    # Read
    data = storage.read("projects/15/robot_spec.json")

    # List
    files = storage.list("projects/15/")

    # Upload from local path
    storage.upload_file("/tmp/render.png", "projects/15/renders/hero.png")
"""

import json
import logging
import os
import shutil
from abc import ABC, abstractmethod
from pathlib import Path
from typing import BinaryIO

logger = logging.getLogger(__name__)


class StorageBackend(ABC):
    """Abstract file storage interface."""

    @abstractmethod
    def read(self, key: str) -> bytes:
        ...

    @abstractmethod
    def read_text(self, key: str, encoding: str = "utf-8") -> str:
        ...

    @abstractmethod
    def write(self, key: str, data: bytes | str, content_type: str = "") -> str:
        ...

    @abstractmethod
    def write_json(self, key: str, obj: dict) -> str:
        ...

    @abstractmethod
    def exists(self, key: str) -> bool:
        ...

    @abstractmethod
    def list(self, prefix: str) -> list[str]:
        ...

    @abstractmethod
    def delete(self, key: str) -> None:
        ...

    @abstractmethod
    def upload_file(self, local_path: str, key: str) -> str:
        ...

    @abstractmethod
    def download_file(self, key: str, local_path: str) -> str:
        ...

    @abstractmethod
    def get_uri(self, key: str) -> str:
        """Return the canonical URI (gs:// or file://) for a key."""
        ...


class LocalStorage(StorageBackend):
    """Local filesystem storage."""

    def __init__(self, base_dir: str | Path):
        self.base = Path(base_dir)
        self.base.mkdir(parents=True, exist_ok=True)

    def _path(self, key: str) -> Path:
        return self.base / key

    def read(self, key: str) -> bytes:
        return self._path(key).read_bytes()

    def read_text(self, key: str, encoding: str = "utf-8") -> str:
        return self._path(key).read_text(encoding=encoding)

    def write(self, key: str, data: bytes | str, content_type: str = "") -> str:
        path = self._path(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(data, str):
            path.write_text(data, encoding="utf-8")
        else:
            path.write_bytes(data)
        return str(path)

    def write_json(self, key: str, obj: dict) -> str:
        return self.write(key, json.dumps(obj, indent=2, ensure_ascii=False))

    def exists(self, key: str) -> bool:
        return self._path(key).exists()

    def list(self, prefix: str) -> list[str]:
        base = self._path(prefix)
        if not base.exists():
            return []
        return [str(p.relative_to(self.base)) for p in base.rglob("*") if p.is_file()]

    def delete(self, key: str) -> None:
        path = self._path(key)
        if path.is_file():
            path.unlink()
        elif path.is_dir():
            shutil.rmtree(path)

    def upload_file(self, local_path: str, key: str) -> str:
        dest = self._path(key)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(local_path, dest)
        return str(dest)

    def download_file(self, key: str, local_path: str) -> str:
        shutil.copy2(self._path(key), local_path)
        return local_path

    def get_uri(self, key: str) -> str:
        return f"file://{self._path(key)}"


class GCSStorage(StorageBackend):
    """Google Cloud Storage backend."""

    def __init__(self, bucket_name: str, project: str | None = None):
        from google.cloud import storage
        self.client = storage.Client(project=project)
        self.bucket = self.client.bucket(bucket_name)
        self.bucket_name = bucket_name
        logger.info(f"[GCS] Using bucket: {bucket_name}")

    def read(self, key: str) -> bytes:
        return self.bucket.blob(key).download_as_bytes()

    def read_text(self, key: str, encoding: str = "utf-8") -> str:
        return self.bucket.blob(key).download_as_text(encoding=encoding)

    def write(self, key: str, data: bytes | str, content_type: str = "") -> str:
        blob = self.bucket.blob(key)
        if isinstance(data, str):
            blob.upload_from_string(data, content_type=content_type or "text/plain")
        else:
            blob.upload_from_string(data, content_type=content_type or "application/octet-stream")
        return f"gs://{self.bucket_name}/{key}"

    def write_json(self, key: str, obj: dict) -> str:
        data = json.dumps(obj, indent=2, ensure_ascii=False)
        return self.write(key, data, content_type="application/json")

    def exists(self, key: str) -> bool:
        return self.bucket.blob(key).exists()

    def list(self, prefix: str) -> list[str]:
        return [b.name for b in self.bucket.list_blobs(prefix=prefix)]

    def delete(self, key: str) -> None:
        blob = self.bucket.blob(key)
        if blob.exists():
            blob.delete()

    def upload_file(self, local_path: str, key: str) -> str:
        blob = self.bucket.blob(key)
        blob.upload_from_filename(local_path)
        return f"gs://{self.bucket_name}/{key}"

    def download_file(self, key: str, local_path: str) -> str:
        self.bucket.blob(key).download_to_filename(local_path)
        return local_path

    def get_uri(self, key: str) -> str:
        return f"gs://{self.bucket_name}/{key}"


# --- Singleton ---

_storage: StorageBackend | None = None


def get_storage() -> StorageBackend:
    """Get the storage backend (auto-detects local vs cloud)."""
    global _storage
    if _storage is not None:
        return _storage

    env = os.getenv("ENVIRONMENT", "local")
    if env == "cloud":
        bucket = os.getenv("GCS_ARTIFACTS_BUCKET", "")
        project = os.getenv("GCP_PROJECT", "")
        if bucket:
            _storage = GCSStorage(bucket, project or None)
        else:
            raise ValueError("ENVIRONMENT=cloud but GCS_ARTIFACTS_BUCKET not set")
    else:
        # Local mode — use planning_server/data as base
        from pathlib import Path
        base = Path(__file__).resolve().parent.parent / "planning_server" / "data"
        _storage = LocalStorage(base)

    return _storage
