import type {
  HealthResponse,
  CapabilitiesResponse,
  DashboardData,
  SimulationJob,
  ProjectInfo,
  LogEntry,
} from "./types";

const PLANNING_BASE = "/api/v1";
const SIM_BASE = "/sim-api/v1";

async function fetchJSON<T>(url: string, options?: RequestInit): Promise<T> {
  const res = await fetch(url, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (!res.ok) {
    throw new Error(`${res.status} ${res.statusText}: ${url}`);
  }
  return res.json();
}

export const api = {
  // Health checks
  planningHealth: () => fetchJSON<HealthResponse>(`${PLANNING_BASE}/health`),
  simulationHealth: () => fetchJSON<HealthResponse>(`${SIM_BASE}/health`),
  simulationCapabilities: () =>
    fetchJSON<CapabilitiesResponse>(`${SIM_BASE}/capabilities`),

  // Dashboard aggregate
  dashboard: () => fetchJSON<DashboardData>(`${PLANNING_BASE}/dashboard`),

  // Simulation jobs
  simulationJobs: () => fetchJSON<SimulationJob[]>(`${PLANNING_BASE}/dashboard/jobs`),

  // Projects
  projects: () => fetchJSON<ProjectInfo[]>(`${PLANNING_BASE}/dashboard/projects`),

  // Logs
  logs: (service?: string, limit?: number) =>
    fetchJSON<LogEntry[]>(
      `${PLANNING_BASE}/dashboard/logs?${new URLSearchParams({
        ...(service && { service }),
        ...(limit && { limit: String(limit) }),
      })}`
    ),

  // GPU info
  gpu: () => fetchJSON<DashboardData["gpu"]>(`${PLANNING_BASE}/dashboard/gpu`),
};
