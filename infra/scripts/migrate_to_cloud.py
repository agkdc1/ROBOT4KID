#!/usr/bin/env python3
"""Migrate local data to GCP cloud infrastructure.

Migrates:
1. SQLite database → Firestore
2. Local project files → GCS artifacts bucket
3. Simulation job files → GCS artifacts bucket

Usage:
    python infra/scripts/migrate_to_cloud.py [--dry-run]

Requires:
    - GCP_PROJECT env var
    - GCS_ARTIFACTS_BUCKET env var
    - ADC configured (gcloud auth application-default login)
"""

import argparse
import json
import logging
import os
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("migrate")

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
SQLITE_DB = PROJECT_ROOT / "planning_server" / "data" / "db.sqlite3"
PROJECTS_DIR = PROJECT_ROOT / "planning_server" / "data" / "projects"
JOBS_DIR = PROJECT_ROOT / "simulation_server" / "jobs"


def migrate_sqlite_to_firestore(dry_run: bool = False):
    """Migrate SQLite tables to Firestore collections."""
    from google.cloud import firestore

    if not SQLITE_DB.exists():
        logger.warning(f"SQLite DB not found: {SQLITE_DB}")
        return

    conn = sqlite3.connect(str(SQLITE_DB))
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    project = os.environ.get("GCP_PROJECT", "nl2bot-f7e604")
    if not dry_run:
        db = firestore.Client(project=project)

    # Migrate users
    cur.execute("SELECT * FROM users")
    users = [dict(row) for row in cur.fetchall()]
    logger.info(f"Users: {len(users)}")
    for user in users:
        doc_id = str(user["id"])
        user.pop("id", None)
        if dry_run:
            logger.info(f"  [DRY] users/{doc_id}: {user.get('username')}")
        else:
            db.collection("users").document(doc_id).set(user)
            logger.info(f"  users/{doc_id}: {user.get('username')}")

    # Migrate projects
    cur.execute("SELECT * FROM projects")
    projects = [dict(row) for row in cur.fetchall()]
    logger.info(f"Projects: {len(projects)}")
    for project_row in projects:
        doc_id = str(project_row["id"])
        project_row["owner_id"] = str(project_row.get("owner_id", ""))
        project_row.pop("id", None)
        if dry_run:
            logger.info(f"  [DRY] projects/{doc_id}: {project_row.get('name')}")
        else:
            db.collection("projects").document(doc_id).set(project_row)
            logger.info(f"  projects/{doc_id}: {project_row.get('name')}")

    # Migrate conversations
    try:
        cur.execute("SELECT * FROM conversations")
        conversations = [dict(row) for row in cur.fetchall()]
        logger.info(f"Conversations: {len(conversations)}")
        for conv in conversations:
            doc_id = str(conv["id"])
            conv["project_id"] = str(conv.get("project_id", ""))
            conv.pop("id", None)
            if not dry_run:
                db.collection("conversations").document(doc_id).set(conv)
    except sqlite3.OperationalError:
        logger.info("No conversations table")

    # Migrate messages
    try:
        cur.execute("SELECT * FROM messages")
        messages = [dict(row) for row in cur.fetchall()]
        logger.info(f"Messages: {len(messages)}")
        for msg in messages:
            doc_id = str(msg["id"])
            msg.pop("id", None)
            if not dry_run:
                db.collection("messages").document(doc_id).set(msg)
    except sqlite3.OperationalError:
        logger.info("No messages table")

    conn.close()
    logger.info("SQLite → Firestore migration complete")


def migrate_files_to_gcs(dry_run: bool = False):
    """Upload project files and job files to GCS."""
    from google.cloud import storage

    bucket_name = os.environ.get("GCS_ARTIFACTS_BUCKET", "nl2bot-f7e604-artifacts")
    project = os.environ.get("GCP_PROJECT", "nl2bot-f7e604")

    if not dry_run:
        client = storage.Client(project=project)
        bucket = client.bucket(bucket_name)

    # Upload project files
    if PROJECTS_DIR.exists():
        for file_path in PROJECTS_DIR.rglob("*"):
            if file_path.is_file():
                key = f"projects/{file_path.relative_to(PROJECTS_DIR)}"
                key = key.replace("\\", "/")
                if dry_run:
                    logger.info(f"  [DRY] {file_path} → gs://{bucket_name}/{key}")
                else:
                    blob = bucket.blob(key)
                    blob.upload_from_filename(str(file_path))
                    logger.info(f"  {file_path.name} → gs://{bucket_name}/{key}")

    # Upload job files
    if JOBS_DIR.exists():
        for file_path in JOBS_DIR.rglob("*"):
            if file_path.is_file():
                key = f"jobs/{file_path.relative_to(JOBS_DIR)}"
                key = key.replace("\\", "/")
                if dry_run:
                    logger.info(f"  [DRY] {file_path} → gs://{bucket_name}/{key}")
                else:
                    blob = bucket.blob(key)
                    blob.upload_from_filename(str(file_path))
                    logger.info(f"  {file_path.name} → gs://{bucket_name}/{key}")

    logger.info("File → GCS migration complete")


def main():
    parser = argparse.ArgumentParser(description="Migrate local data to GCP cloud")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be migrated without executing")
    parser.add_argument("--db-only", action="store_true", help="Only migrate SQLite → Firestore")
    parser.add_argument("--files-only", action="store_true", help="Only migrate files → GCS")
    args = parser.parse_args()

    logger.info("=" * 60)
    logger.info("ROBOT4KID Cloud Migration")
    logger.info("=" * 60)
    if args.dry_run:
        logger.info("*** DRY RUN — no changes will be made ***")

    if not args.files_only:
        logger.info("\n--- Phase 1: SQLite → Firestore ---")
        migrate_sqlite_to_firestore(dry_run=args.dry_run)

    if not args.db_only:
        logger.info("\n--- Phase 2: Files → GCS ---")
        migrate_files_to_gcs(dry_run=args.dry_run)

    logger.info("\n--- Migration Complete ---")


if __name__ == "__main__":
    main()
