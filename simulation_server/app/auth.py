"""API key authentication for simulation server."""

from fastapi import HTTPException, Security, status
from fastapi.security import APIKeyHeader

from simulation_server.app import config

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


async def require_api_key(api_key: str | None = Security(api_key_header)) -> str:
    """Validate API key. If SIM_API_KEY is empty, auth is disabled (dev mode)."""
    if not config.SIM_API_KEY:
        return "dev-mode"
    if api_key and api_key == config.SIM_API_KEY:
        return api_key
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or missing API key",
    )
