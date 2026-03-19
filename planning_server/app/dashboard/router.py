"""Dashboard API — system metrics, GPU status, services, jobs, projects, logs."""

import os
import time
import subprocess
import platform
from pathlib import Path
from datetime import datetime, timezone

import httpx
from fastapi import APIRouter, Query

from planning_server.app import config

router = APIRouter(prefix="/dashboard", tags=["dashboard"])

_BOOT_TIME = time.time()


def _run_cmd(cmd: list[str], timeout: int = 5) -> str:
    """Run a subprocess and return stdout, or empty string on failure."""
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout
        )
        return result.stdout.strip()
    except Exception:
        return ""


def _get_system_metrics() -> dict:
    """CPU, RAM, disk metrics via cross-platform commands."""
    metrics = {
        "cpu_pct": 0.0,
        "ram_used_mb": 0,
        "ram_total_mb": 0,
        "disk_used_gb": 0,
        "disk_total_gb": 0,
        "uptime_seconds": int(time.time() - _BOOT_TIME),
    }

    if platform.system() == "Windows":
        # CPU via wmic
        cpu_out = _run_cmd(
            ["wmic", "cpu", "get", "LoadPercentage", "/value"]
        )
        for line in cpu_out.splitlines():
            if "LoadPercentage" in line:
                try:
                    metrics["cpu_pct"] = float(line.split("=")[1])
                except (ValueError, IndexError):
                    pass

        # RAM via wmic
        ram_out = _run_cmd(
            ["wmic", "OS", "get", "TotalVisibleMemorySize,FreePhysicalMemory", "/value"]
        )
        total_kb = free_kb = 0
        for line in ram_out.splitlines():
            if "TotalVisibleMemorySize" in line:
                try:
                    total_kb = int(line.split("=")[1])
                except (ValueError, IndexError):
                    pass
            elif "FreePhysicalMemory" in line:
                try:
                    free_kb = int(line.split("=")[1])
                except (ValueError, IndexError):
                    pass
        metrics["ram_total_mb"] = total_kb // 1024
        metrics["ram_used_mb"] = (total_kb - free_kb) // 1024

        # Disk
        disk_out = _run_cmd(
            ["wmic", "logicaldisk", "where", "DeviceID='C:'", "get", "Size,FreeSpace", "/value"]
        )
        size_bytes = free_bytes = 0
        for line in disk_out.splitlines():
            if line.startswith("FreeSpace"):
                try:
                    free_bytes = int(line.split("=")[1])
                except (ValueError, IndexError):
                    pass
            elif line.startswith("Size"):
                try:
                    size_bytes = int(line.split("=")[1])
                except (ValueError, IndexError):
                    pass
        metrics["disk_total_gb"] = round(size_bytes / (1024**3), 1)
        metrics["disk_used_gb"] = round((size_bytes - free_bytes) / (1024**3), 1)

    return metrics


def _get_gpu_status() -> dict | None:
    """Query NVIDIA GPU via nvidia-smi."""
    smi = _run_cmd([
        "nvidia-smi",
        "--query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw,power.limit,fan.speed,driver_version",
        "--format=csv,noheader,nounits",
    ])
    if not smi:
        return None

    try:
        parts = [p.strip() for p in smi.split(",")]
        return {
            "name": parts[0],
            "temperature_c": int(parts[1]),
            "utilization_pct": int(parts[2]),
            "memory_used_mb": int(float(parts[3])),
            "memory_total_mb": int(float(parts[4])),
            "power_draw_w": round(float(parts[5]), 1),
            "power_limit_w": round(float(parts[6]), 1),
            "fan_speed_pct": int(parts[7]) if parts[7] != "[N/A]" else 0,
            "driver_version": parts[8],
        }
    except (IndexError, ValueError):
        return None


def _get_services() -> list[dict]:
    """Query NSSM services status."""
    service_names = [
        ("NL2Bot-Planning", "Planning Server"),
        ("NL2Bot-Simulation", "Simulation Server"),
        ("NL2Bot-Tunnel", "Cloudflare Tunnel"),
    ]
    services = []
    for name, display in service_names:
        status = _run_cmd(["sc", "query", name])
        running = "RUNNING" in status
        pid = None
        if running:
            pid_line = _run_cmd(["sc", "queryex", name])
            for line in pid_line.splitlines():
                if "PID" in line and ":" in line:
                    try:
                        pid = int(line.split(":")[1].strip())
                    except (ValueError, IndexError):
                        pass
        services.append({
            "name": name,
            "display_name": display,
            "status": "running" if running else "stopped",
            "pid": pid,
        })
    return services


async def _check_server(port: int, name: str) -> dict:
    """Health-check a server."""
    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            resp = await client.get(f"http://localhost:{port}/api/v1/health")
            data = resp.json()

            caps = None
            if port == 8100:
                try:
                    caps_resp = await client.get(
                        f"http://localhost:{port}/api/v1/capabilities",
                        headers={"X-API-Key": os.getenv("SIM_API_KEY", "")},
                    )
                    caps = caps_resp.json()
                except Exception:
                    pass

            return {
                "name": name,
                "port": port,
                "status": "online",
                "version": data.get("version", "unknown"),
                "uptime_seconds": int(time.time() - _BOOT_TIME),
                "capabilities": caps,
            }
    except Exception:
        return {
            "name": name,
            "port": port,
            "status": "offline",
            "version": "—",
            "uptime_seconds": 0,
            "capabilities": None,
        }


@router.get("")
async def dashboard_aggregate():
    """Full dashboard data: servers, GPU, system, services."""
    planning = await _check_server(8000, "Planning Server")
    simulation = await _check_server(8100, "Simulation Server")

    return {
        "servers": [planning, simulation],
        "gpu": _get_gpu_status(),
        "system": _get_system_metrics(),
        "services": _get_services(),
    }


@router.get("/gpu")
async def gpu_status():
    return _get_gpu_status()


@router.get("/jobs")
async def simulation_jobs():
    """List simulation jobs from the simulation server jobs directory."""
    jobs_dir = Path(__file__).resolve().parent.parent.parent.parent / "simulation_server" / "jobs"
    jobs = []
    if jobs_dir.exists():
        for job_dir in sorted(jobs_dir.iterdir(), reverse=True):
            if job_dir.is_dir():
                status_file = job_dir / "status.json"
                if status_file.exists():
                    import json
                    try:
                        with open(status_file, "r", encoding="utf-8") as f:
                            data = json.load(f)
                        jobs.append(data)
                    except Exception:
                        pass
                else:
                    jobs.append({
                        "job_id": job_dir.name,
                        "status": "unknown",
                        "model_type": "tank",
                        "created_at": datetime.fromtimestamp(
                            job_dir.stat().st_ctime, tz=timezone.utc
                        ).isoformat(),
                        "updated_at": datetime.fromtimestamp(
                            job_dir.stat().st_mtime, tz=timezone.utc
                        ).isoformat(),
                        "progress_pct": 0,
                        "current_step": "unknown",
                    })
    return jobs[:50]


@router.get("/projects")
async def list_projects():
    """List projects from the planning server database."""
    from shared.db_backend import get_db_backend

    projects = []
    try:
        db = get_db_backend()
        all_projects = await db.list_all_projects(limit=100)
        for proj in all_projects:
            projects.append({
                "id": str(proj["id"]),
                "name": proj.get("name", ""),
                "description": proj.get("description", ""),
                "model_type": proj.get("model_type", "tank"),
                "status": proj.get("status", "active"),
                "created_at": proj.get("created_at", ""),
                "updated_at": proj.get("updated_at", ""),
                "parts_count": 0,
                "last_simulation": None,
            })
    except Exception:
        pass
    return projects


@router.get("/logs")
async def get_logs(
    service: str | None = Query(None),
    limit: int = Query(100, le=500),
):
    """Read recent log entries from log files."""
    logs_dir = Path(__file__).resolve().parent.parent.parent.parent / "logs"
    entries: list[dict] = []

    if not logs_dir.exists():
        return entries

    for log_file in logs_dir.glob("*.log"):
        if service and service.lower() not in log_file.name.lower():
            continue
        try:
            with open(log_file, "r", encoding="utf-8", errors="ignore") as f:
                lines = f.readlines()
            svc_name = log_file.stem
            for line in lines[-limit:]:
                line = line.strip()
                if not line:
                    continue
                level = "info"
                for lvl in ["ERROR", "WARNING", "WARN", "DEBUG"]:
                    if lvl in line.upper():
                        level = lvl.lower().replace("warn", "warning")
                        break
                entries.append({
                    "timestamp": datetime.now(tz=timezone.utc).isoformat(),
                    "level": level,
                    "service": svc_name,
                    "message": line[:500],
                })
        except Exception:
            pass

    entries.sort(key=lambda e: e["timestamp"], reverse=True)
    return entries[:limit]
