"""Shared fixtures for NL2Bot integration tests.

Provides base URLs, auth tokens, API keys, and helper utilities
loaded from the project .env file.
"""

import os
import sys
import time
from pathlib import Path

import pytest

# Add project root to path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from dotenv import load_dotenv

load_dotenv(PROJECT_ROOT / ".env")


# ---------------------------------------------------------------------------
# Configuration constants
# ---------------------------------------------------------------------------

PLANNING_URL = os.getenv("PLANNING_SERVER_URL", "http://localhost:8000")
SIMULATION_URL = os.getenv("SIMULATION_SERVER_URL", "http://localhost:8100")
SIM_API_KEY = os.getenv("SIM_API_KEY", "")
ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "admin")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "admin")

# Unique test-user name per run to avoid conflicts
TEST_USERNAME = f"test_user_{int(time.time())}"
TEST_PASSWORD = "testpass123"


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def planning_url() -> str:
    return PLANNING_URL


@pytest.fixture(scope="session")
def simulation_url() -> str:
    return SIMULATION_URL


@pytest.fixture(scope="session")
def sim_api_key() -> str:
    return SIM_API_KEY


@pytest.fixture(scope="session")
def sim_headers() -> dict:
    """Headers for simulation server requests (API key auth)."""
    headers = {"Content-Type": "application/json"}
    if SIM_API_KEY:
        headers["X-API-Key"] = SIM_API_KEY
    return headers


@pytest.fixture(scope="session")
def admin_token(planning_url: str) -> str:
    """Log in as admin and return the JWT access token."""
    import httpx

    resp = httpx.post(
        f"{planning_url}/api/v1/auth/login",
        data={"username": ADMIN_USERNAME, "password": ADMIN_PASSWORD},
    )
    assert resp.status_code == 200, f"Admin login failed: {resp.text}"
    return resp.json()["access_token"]


@pytest.fixture(scope="session")
def admin_headers(admin_token: str) -> dict:
    """Authorization headers for admin endpoints."""
    return {
        "Authorization": f"Bearer {admin_token}",
        "Content-Type": "application/json",
    }


@pytest.fixture(scope="session")
def test_user_token(planning_url: str, admin_token: str) -> str:
    """Register a test user, approve via admin, and return the user JWT."""
    import httpx

    # 1. Register
    resp = httpx.post(
        f"{planning_url}/api/v1/auth/register",
        json={"username": TEST_USERNAME, "password": TEST_PASSWORD},
    )
    assert resp.status_code == 201, f"Registration failed: {resp.text}"
    user_id = resp.json()["id"]

    # 2. Admin approves
    resp = httpx.post(
        f"{planning_url}/api/v1/admin/users/{user_id}/approve",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200, f"Approval failed: {resp.text}"

    # 3. User login
    resp = httpx.post(
        f"{planning_url}/api/v1/auth/login",
        data={"username": TEST_USERNAME, "password": TEST_PASSWORD},
    )
    assert resp.status_code == 200, f"User login failed: {resp.text}"
    return resp.json()["access_token"]


@pytest.fixture(scope="session")
def user_headers(test_user_token: str) -> dict:
    """Authorization headers for regular user endpoints."""
    return {
        "Authorization": f"Bearer {test_user_token}",
        "Content-Type": "application/json",
    }
