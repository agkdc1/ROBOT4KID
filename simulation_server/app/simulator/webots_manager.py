"""Webots process lifecycle manager.

Provides async helpers to start, stop, and monitor a Webots simulation
process. Designed for headless (no-rendering) operation suitable for
server-side CI/CD and automated testing.
"""

from __future__ import annotations

import asyncio
import logging
import os
import platform
import signal
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# Default Webots binary locations
_WEBOTS_PATHS: dict[str, list[str]] = {
    "Windows": [
        r"C:\Program Files\Webots\msys64\mingw64\bin\webots.exe",
        r"C:\Program Files (x86)\Webots\msys64\mingw64\bin\webots.exe",
    ],
    "Linux": [
        "/usr/local/bin/webots",
        "/usr/bin/webots",
        "/snap/bin/webots",
    ],
    "Darwin": [
        "/Applications/Webots.app/Contents/MacOS/webots",
    ],
}


def _find_webots_binary() -> str:
    """Locate the Webots executable on the current platform.

    Returns the path from the WEBOTS_HOME env var if set, otherwise
    searches common install locations.
    """
    # Env override
    webots_home = os.environ.get("WEBOTS_HOME")
    if webots_home:
        for name in ("webots", "webots.exe"):
            candidate = Path(webots_home) / name
            if candidate.exists():
                return str(candidate)
            candidate = Path(webots_home) / "msys64" / "mingw64" / "bin" / name
            if candidate.exists():
                return str(candidate)

    # Platform search
    system = platform.system()
    candidates = _WEBOTS_PATHS.get(system, [])
    for path in candidates:
        if Path(path).exists():
            return path

    # Fallback — assume it is on PATH
    return "webots"


class WebotsManager:
    """Manages a single Webots simulation process."""

    def __init__(self) -> None:
        self._process: Optional[asyncio.subprocess.Process] = None
        self._world_path: Optional[Path] = None
        self._binary: str = _find_webots_binary()
        self._stdout_task: Optional[asyncio.Task[None]] = None
        self._stderr_task: Optional[asyncio.Task[None]] = None
        # Streaming state
        self._streaming: bool = False
        self._stream_port: Optional[int] = None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def start_simulation(
        self,
        world_path: Path | str,
        *,
        mode: str = "headless",
        stream_port: int = 1234,
        extra_args: list[str] | None = None,
        env: dict[str, str] | None = None,
    ) -> None:
        """Launch Webots with the given world file.

        Args:
            world_path: Absolute path to the .wbt world file.
            mode: Launch mode — ``"headless"`` (no rendering, default) or
                ``"stream"`` (web streaming via ``--stream``).
            stream_port: TCP port for the Webots web-streaming WebSocket
                server.  Only used when *mode* is ``"stream"``.
            extra_args: Additional CLI flags for Webots.
            env: Extra environment variables (merged with os.environ).
        """
        if mode not in ("headless", "stream"):
            raise ValueError(f"Invalid mode '{mode}'. Must be 'headless' or 'stream'.")

        world_path = Path(world_path).resolve()
        if not world_path.exists():
            raise FileNotFoundError(f"World file not found: {world_path}")

        if self.is_running():
            logger.warning("Simulation already running — stopping first")
            await self.stop_simulation()

        if mode == "stream":
            cmd = [
                self._binary,
                "--stream",
                f"--stream=port={stream_port}",
                "--no-gui",
                "--batch",
                "--stdout",
                "--stderr",
                str(world_path),
            ]
        else:
            cmd = [
                self._binary,
                "--no-rendering",
                "--stdout",
                "--stderr",
                "--minimize",
                "--batch",
                str(world_path),
            ]

        if extra_args:
            cmd.extend(extra_args)

        merged_env = dict(os.environ)
        if env:
            merged_env.update(env)

        logger.info("Starting Webots (%s): %s", mode, " ".join(cmd))
        self._process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env=merged_env,
        )
        self._world_path = world_path
        self._streaming = mode == "stream"
        self._stream_port = stream_port if self._streaming else None

        # Background tasks to drain stdout/stderr
        self._stdout_task = asyncio.create_task(
            self._log_stream(self._process.stdout, "webots:stdout")
        )
        self._stderr_task = asyncio.create_task(
            self._log_stream(self._process.stderr, "webots:stderr")
        )

        logger.info("Webots started (PID %d, mode=%s)", self._process.pid, mode)

    async def start_streaming(
        self,
        world_path: Path | str,
        *,
        port: int = 1234,
        extra_args: list[str] | None = None,
        env: dict[str, str] | None = None,
    ) -> dict:
        """Launch Webots in web-streaming mode.

        This is a convenience wrapper around :meth:`start_simulation` with
        ``mode="stream"``.

        Args:
            world_path: Absolute path to the ``.wbt`` world file.
            port: TCP port for the Webots web-streaming WebSocket server.
            extra_args: Additional CLI flags for Webots.
            env: Extra environment variables (merged with os.environ).

        Returns:
            A dict with ``ws_url`` and ``pid``.
        """
        await self.start_simulation(
            world_path,
            mode="stream",
            stream_port=port,
            extra_args=extra_args,
            env=env,
        )
        return {
            "ws_url": f"ws://localhost:{port}",
            "pid": self.pid,
        }

    def get_stream_url(self) -> Optional[str]:
        """Return the WebSocket URL if streaming is active, else None."""
        if self.is_running() and self._streaming and self._stream_port is not None:
            return f"ws://localhost:{self._stream_port}"
        return None

    async def stop_simulation(self, timeout: float = 10.0) -> None:
        """Gracefully stop the Webots process.

        Sends SIGTERM (or terminates on Windows) and waits up to
        *timeout* seconds before force-killing.
        """
        if self._process is None:
            return

        pid = self._process.pid
        logger.info("Stopping Webots (PID %d)", pid)

        try:
            self._process.terminate()
            try:
                await asyncio.wait_for(self._process.wait(), timeout=timeout)
            except asyncio.TimeoutError:
                logger.warning("Webots did not exit in %.1fs — killing", timeout)
                self._process.kill()
                await self._process.wait()
        except ProcessLookupError:
            pass  # already exited
        finally:
            self._cancel_log_tasks()
            self._process = None
            self._streaming = False
            self._stream_port = None
            logger.info("Webots stopped (was PID %d)", pid)

    def is_running(self) -> bool:
        """Return True if the Webots process is alive."""
        if self._process is None:
            return False
        return self._process.returncode is None

    def get_process(self) -> Optional[asyncio.subprocess.Process]:
        """Return the underlying asyncio subprocess, or None."""
        return self._process

    @property
    def world_path(self) -> Optional[Path]:
        return self._world_path

    @property
    def pid(self) -> Optional[int]:
        return self._process.pid if self._process else None

    @property
    def is_streaming(self) -> bool:
        """Return True if Webots is running in streaming mode."""
        return self._streaming and self.is_running()

    @property
    def stream_port(self) -> Optional[int]:
        """Return the streaming port if active, else None."""
        return self._stream_port if self._streaming else None

    # ------------------------------------------------------------------
    # Internals
    # ------------------------------------------------------------------

    @staticmethod
    async def _log_stream(
        stream: Optional[asyncio.StreamReader],
        prefix: str,
    ) -> None:
        """Read lines from *stream* and log them."""
        if stream is None:
            return
        try:
            while True:
                line = await stream.readline()
                if not line:
                    break
                text = line.decode("utf-8", errors="replace").rstrip()
                if text:
                    logger.debug("[%s] %s", prefix, text)
        except asyncio.CancelledError:
            pass

    def _cancel_log_tasks(self) -> None:
        for task in (self._stdout_task, self._stderr_task):
            if task is not None and not task.done():
                task.cancel()
        self._stdout_task = None
        self._stderr_task = None

    # ------------------------------------------------------------------
    # Context manager
    # ------------------------------------------------------------------

    async def __aenter__(self) -> "WebotsManager":
        return self

    async def __aexit__(self, *exc: object) -> None:
        await self.stop_simulation()


# Module-level singleton for simple use-cases
_default_manager: Optional[WebotsManager] = None


def get_manager() -> WebotsManager:
    """Return (and lazily create) the module-level WebotsManager."""
    global _default_manager
    if _default_manager is None:
        _default_manager = WebotsManager()
    return _default_manager
