export interface HealthResponse {
  status: string;
  service: string;
  version: string;
}

export interface CapabilitiesResponse {
  render: boolean;
  assemble: boolean;
  physics: boolean;
  printability: boolean;
  viewer: boolean;
  ballistics_training: boolean;
}

export interface ServerStatus {
  name: string;
  port: number;
  status: "online" | "offline" | "degraded";
  version: string;
  uptime_seconds: number;
  capabilities?: CapabilitiesResponse;
}

export interface GPUStatus {
  name: string;
  temperature_c: number;
  utilization_pct: number;
  memory_used_mb: number;
  memory_total_mb: number;
  power_draw_w: number;
  power_limit_w: number;
  fan_speed_pct: number;
  driver_version: string;
}

export interface SystemMetrics {
  cpu_pct: number;
  ram_used_mb: number;
  ram_total_mb: number;
  disk_used_gb: number;
  disk_total_gb: number;
  uptime_seconds: number;
}

export interface ServiceInfo {
  name: string;
  display_name: string;
  status: "running" | "stopped" | "unknown";
  pid?: number;
}

export interface DashboardData {
  servers: ServerStatus[];
  gpu: GPUStatus | null;
  system: SystemMetrics;
  services: ServiceInfo[];
}

export interface SimulationJob {
  job_id: string;
  status: "pending" | "running" | "completed" | "failed";
  model_type: "tank" | "train";
  created_at: string;
  updated_at: string;
  progress_pct: number;
  current_step: string;
  error?: string;
}

export interface ProjectInfo {
  id: string;
  name: string;
  description: string;
  model_type: "tank" | "train";
  status: "active" | "archived" | "draft";
  created_at: string;
  updated_at: string;
  parts_count: number;
  last_simulation?: string;
}

export interface LogEntry {
  timestamp: string;
  level: "info" | "warning" | "error" | "debug";
  service: string;
  message: string;
}
