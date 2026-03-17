import { useState, useCallback } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  Radio,
  Clock,
  AlertTriangle,
  Server,
  Globe,
} from "lucide-react";
import { SimulationViewer } from "@/components/SimulationViewer";
import { Panel } from "@/components/ui/Panel";
import { DataField } from "@/components/ui/DataField";
import { StatusBadge } from "@/components/ui/StatusBadge";

const SIM_BASE = "/sim-api/v1";

interface StreamStatus {
  running: boolean;
  stream_url: string | null;
  ws_url: string | null;
  job_id: string | null;
  uptime_seconds?: number;
}

async function fetchStreamStatus(): Promise<StreamStatus> {
  const res = await fetch(`${SIM_BASE}/webots/stream/status`, {
    headers: { "Content-Type": "application/json" },
  });
  if (!res.ok) {
    // If the endpoint doesn't exist yet, return a default
    if (res.status === 404) {
      return { running: false, stream_url: null, ws_url: null, job_id: null };
    }
    throw new Error(`${res.status} ${res.statusText}`);
  }
  return res.json();
}

async function startStream(jobId: string): Promise<StreamStatus> {
  const res = await fetch(`${SIM_BASE}/webots/stream/start`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ job_id: jobId }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Failed to start stream: ${res.status} ${text}`);
  }
  return res.json();
}

async function stopStream(): Promise<void> {
  const res = await fetch(`${SIM_BASE}/webots/stream/stop`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
  });
  if (!res.ok) {
    throw new Error(`Failed to stop stream: ${res.status}`);
  }
}

export function SimulationPage() {
  const queryClient = useQueryClient();
  const [jobIdInput, setJobIdInput] = useState("default");
  const [error, setError] = useState<string | null>(null);

  const { data: status, isLoading } = useQuery({
    queryKey: ["webots-stream-status"],
    queryFn: fetchStreamStatus,
    refetchInterval: 5000,
    retry: 1,
  });

  const startMutation = useMutation({
    mutationFn: (jobId: string) => startStream(jobId),
    onSuccess: () => {
      setError(null);
      queryClient.invalidateQueries({ queryKey: ["webots-stream-status"] });
    },
    onError: (err: Error) => {
      setError(err.message);
    },
  });

  const stopMutation = useMutation({
    mutationFn: () => stopStream(),
    onSuccess: () => {
      setError(null);
      queryClient.invalidateQueries({ queryKey: ["webots-stream-status"] });
    },
    onError: (err: Error) => {
      setError(err.message);
    },
  });

  const handleStart = useCallback(() => {
    if (!jobIdInput.trim()) return;
    setError(null);
    startMutation.mutate(jobIdInput.trim());
  }, [jobIdInput, startMutation]);

  const handleStop = useCallback(() => {
    setError(null);
    stopMutation.mutate();
  }, [stopMutation]);

  const isRunning = status?.running ?? false;
  const activeJobId = status?.job_id ?? jobIdInput;
  const streamUrl = status?.stream_url ?? null;
  const wsUrl = status?.ws_url ?? null;

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-amber-500 data-readout text-sm tracking-widest animate-pulse">
          QUERYING SIMULATION STATUS...
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6">
      {/* Page header */}
      <div className="flex items-center justify-between">
        <div>
          <h2
            className="text-2xl font-bold tracking-[0.15em] text-text-primary"
            style={{ fontFamily: "var(--font-display)" }}
          >
            SIMULATION
          </h2>
          <p className="text-xs text-text-muted tracking-wider mt-1">
            Webots physics simulation viewer
          </p>
        </div>
        <div className="data-readout text-xs text-text-muted">
          <Clock className="w-3 h-3 inline mr-1" />
          {new Date().toLocaleTimeString()}
        </div>
      </div>

      {/* Error banner */}
      {error && (
        <div className="flex items-center gap-3 px-4 py-3 rounded-sm bg-signal-red/10 border border-signal-red/30">
          <AlertTriangle className="w-4 h-4 text-signal-red shrink-0" />
          <span className="text-sm text-signal-red">{error}</span>
          <button
            onClick={() => setError(null)}
            className="ml-auto text-xs text-signal-red/60 hover:text-signal-red tracking-widest"
          >
            DISMISS
          </button>
        </div>
      )}

      {/* Control strip */}
      <div className="grid grid-cols-3 gap-4">
        <Panel title="Job Config" icon={<Server className="w-3.5 h-3.5" />}>
          <div className="space-y-3">
            <div>
              <label
                className="block text-[10px] text-text-muted tracking-widest uppercase mb-1.5"
                style={{ fontFamily: "var(--font-display)" }}
              >
                Job ID
              </label>
              <input
                type="text"
                value={isRunning ? activeJobId : jobIdInput}
                onChange={(e) => setJobIdInput(e.target.value)}
                disabled={isRunning}
                className="w-full px-3 py-2 bg-bg-primary border border-border-dim rounded-sm text-sm text-text-primary data-readout tracking-wider focus:outline-none focus:border-cyan-500/50 disabled:opacity-50"
                placeholder="Enter job ID"
              />
            </div>
          </div>
        </Panel>

        <Panel title="Stream Status" icon={<Radio className="w-3.5 h-3.5" />}>
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-[10px] text-text-muted tracking-widest uppercase">
                State
              </span>
              <StatusBadge
                status={isRunning ? "running" : "stopped"}
                pulse={isRunning}
              />
            </div>
            {isRunning && status?.uptime_seconds != null && (
              <DataField
                label="Uptime"
                value={`${Math.floor(status.uptime_seconds)}s`}
              />
            )}
          </div>
        </Panel>

        <Panel title="Endpoints" icon={<Globe className="w-3.5 h-3.5" />}>
          <div className="space-y-2">
            <div>
              <span className="block text-[10px] text-text-muted tracking-widest uppercase mb-0.5">
                Stream
              </span>
              <span className="text-xs data-readout text-text-secondary truncate block">
                {streamUrl ?? "---"}
              </span>
            </div>
            <div>
              <span className="block text-[10px] text-text-muted tracking-widest uppercase mb-0.5">
                WebSocket
              </span>
              <span className="text-xs data-readout text-text-secondary truncate block">
                {wsUrl ?? "---"}
              </span>
            </div>
          </div>
        </Panel>
      </div>

      {/* Simulation viewer */}
      <SimulationViewer
        jobId={activeJobId}
        wsUrl={wsUrl ?? undefined}
        streamHttpUrl={streamUrl ?? undefined}
        isRunning={isRunning}
        onStart={handleStart}
        onStop={handleStop}
      />
    </div>
  );
}
