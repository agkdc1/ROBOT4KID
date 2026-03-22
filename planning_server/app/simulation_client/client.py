"""HTTP client for the Simulation Server."""

import asyncio
import logging
import os

import httpx

from planning_server.app import config
from shared.schemas.robot_spec import RobotSpec
from shared.schemas.simulation_request import SimulationRequest

logger = logging.getLogger(__name__)


class SimulationClient:
    """Client for communicating with the Simulation Server."""

    def __init__(self, base_url: str | None = None):
        self.base_url = (base_url or config.SIMULATION_SERVER_URL).rstrip("/")

    def _auth_headers(self) -> dict:
        """Return auth headers for simulation server."""
        headers = {}
        api_key = getattr(config, 'SIM_API_KEY', '') or os.getenv('SIM_API_KEY', '')
        if api_key:
            headers["X-API-Key"] = api_key
        # Cloud mode: add Worker secret for Cloud Run gate
        worker_secret = os.getenv('CF_WORKER_SECRET', '').strip()
        if worker_secret:
            headers["X-Worker-Secret"] = worker_secret
        return headers

    async def health_check(self) -> dict:
        """Check if the simulation server is healthy."""
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v1/health",
                timeout=10,
                headers=self._auth_headers(),
            )
            response.raise_for_status()
            return response.json()

    async def submit_simulation(
        self,
        job_id: str,
        robot_spec: RobotSpec,
        simulation_type: str = "full",
        parameters: dict | None = None,
    ) -> dict:
        """Submit a simulation job."""
        request = SimulationRequest(
            job_id=job_id,
            robot_spec=robot_spec,
            simulation_type=simulation_type,
            parameters=parameters or {},
        )

        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/api/v1/simulate",
                json=request.model_dump(),
                timeout=30,
                headers=self._auth_headers(),
            )
            response.raise_for_status()
            return response.json()

    async def get_job_status(self, job_id: str) -> dict:
        """Get the status of a simulation job."""
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v1/jobs/{job_id}",
                timeout=10,
                headers=self._auth_headers(),
            )
            response.raise_for_status()
            return response.json()

    async def get_feedback(self, job_id: str) -> dict:
        """Get simulation feedback for a completed job."""
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v1/jobs/{job_id}/feedback",
                timeout=10,
                headers=self._auth_headers(),
            )
            response.raise_for_status()
            return response.json()

    async def start_webots(self, job_id: str, convert_urdf: bool = True) -> dict:
        """Start Webots simulation for a job."""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/api/v1/webots/start",
                json={"job_id": job_id, "convert_urdf": convert_urdf},
                timeout=30,
                headers=self._auth_headers(),
            )
            response.raise_for_status()
            return response.json()

    async def stop_webots(self) -> dict:
        """Stop Webots simulation."""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/api/v1/webots/stop",
                json={},
                timeout=10,
                headers=self._auth_headers(),
            )
            response.raise_for_status()
            return response.json()

    async def get_webots_status(self) -> dict:
        """Get Webots simulation status."""
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v1/webots/status",
                timeout=10,
                headers=self._auth_headers(),
            )
            response.raise_for_status()
            return response.json()

    async def wait_for_feedback(
        self,
        job_id: str,
        timeout: float = 300,
        poll_interval: float = 2.0,
    ) -> dict | None:
        """Poll until the job completes and return feedback.

        Args:
            job_id: The simulation job ID.
            timeout: Max wait time in seconds.
            poll_interval: Time between polls in seconds.

        Returns:
            Feedback dict, or None if timeout.
        """
        elapsed = 0.0
        while elapsed < timeout:
            try:
                status = await self.get_job_status(job_id)
                if status.get("status") in ("completed", "failed"):
                    return await self.get_feedback(job_id)
            except httpx.HTTPError as e:
                logger.debug(f"Poll error (will retry): {e}")

            await asyncio.sleep(poll_interval)
            elapsed += poll_interval

        logger.warning(f"Simulation job {job_id} timed out after {timeout}s")
        return None
