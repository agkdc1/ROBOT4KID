import { useQuery } from "@tanstack/react-query";
import { api } from "@/api/client";

export function useDashboard() {
  return useQuery({
    queryKey: ["dashboard"],
    queryFn: api.dashboard,
    refetchInterval: 5000,
    retry: 1,
  });
}

export function usePlanningHealth() {
  return useQuery({
    queryKey: ["health", "planning"],
    queryFn: api.planningHealth,
    refetchInterval: 10000,
    retry: 1,
  });
}

export function useSimulationHealth() {
  return useQuery({
    queryKey: ["health", "simulation"],
    queryFn: api.simulationHealth,
    refetchInterval: 10000,
    retry: 1,
  });
}

export function useSimulationCapabilities() {
  return useQuery({
    queryKey: ["capabilities"],
    queryFn: api.simulationCapabilities,
    refetchInterval: 30000,
    retry: 1,
  });
}

export function useSimulationJobs() {
  return useQuery({
    queryKey: ["jobs"],
    queryFn: api.simulationJobs,
    refetchInterval: 5000,
    retry: 1,
  });
}

export function useProjects() {
  return useQuery({
    queryKey: ["projects"],
    queryFn: api.projects,
    refetchInterval: 15000,
    retry: 1,
  });
}

export function useLogs(service?: string) {
  return useQuery({
    queryKey: ["logs", service],
    queryFn: () => api.logs(service, 100),
    refetchInterval: 3000,
    retry: 1,
  });
}
