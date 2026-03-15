import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatBytes(bytes: number): string {
  if (bytes === 0) return "0 B";
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB", "TB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
}

export function formatUptime(seconds: number): string {
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (d > 0) return `${d}d ${h}h ${m}m`;
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

export function getStatusColor(status: string): string {
  switch (status.toLowerCase()) {
    case "ok":
    case "running":
    case "online":
    case "healthy":
      return "text-signal-green";
    case "warning":
    case "degraded":
      return "text-signal-yellow";
    case "error":
    case "offline":
    case "stopped":
    case "failed":
      return "text-signal-red";
    default:
      return "text-text-secondary";
  }
}

export function getStatusDot(status: string): string {
  switch (status.toLowerCase()) {
    case "ok":
    case "running":
    case "online":
    case "healthy":
      return "bg-signal-green";
    case "warning":
    case "degraded":
      return "bg-signal-yellow";
    case "error":
    case "offline":
    case "stopped":
    case "failed":
      return "bg-signal-red";
    default:
      return "bg-text-muted";
  }
}
