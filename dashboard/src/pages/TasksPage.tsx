import { useState } from "react";
import {
  ListTodo,
  Play,
  CheckCircle,
  XCircle,
  Clock,
  Loader2,
  Filter,
  Terminal,
} from "lucide-react";
import { Panel } from "@/components/ui/Panel";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { useSimulationJobs, useLogs } from "@/hooks/useQueries";
import { cn } from "@/lib/utils";
import type { SimulationJob, LogEntry } from "@/api/types";

const JOB_STATUS_ICON: Record<string, typeof Play> = {
  pending: Clock,
  running: Loader2,
  completed: CheckCircle,
  failed: XCircle,
};

function JobRow({ job }: { job: SimulationJob }) {
  const Icon = JOB_STATUS_ICON[job.status] ?? Clock;
  const isRunning = job.status === "running";

  return (
    <div
      className={cn(
        "flex items-center gap-4 px-4 py-3 rounded-sm border transition-all",
        isRunning
          ? "border-amber-500/30 bg-amber-500/5"
          : "border-border-dim bg-bg-secondary"
      )}
    >
      <Icon
        className={cn(
          "w-4 h-4 shrink-0",
          isRunning && "animate-spin text-amber-400",
          job.status === "completed" && "text-signal-green",
          job.status === "failed" && "text-signal-red",
          job.status === "pending" && "text-text-muted"
        )}
      />
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className="data-readout text-sm text-text-primary truncate">
            {job.job_id}
          </span>
          <span
            className={cn(
              "text-[10px] px-1.5 py-0.5 rounded uppercase tracking-wider",
              job.model_type === "tank"
                ? "bg-signal-green/10 text-signal-green"
                : "bg-signal-blue/10 text-signal-blue"
            )}
          >
            {job.model_type}
          </span>
        </div>
        <div className="text-xs text-text-muted mt-0.5">
          {job.current_step}
        </div>
      </div>

      {isRunning && (
        <div className="w-24">
          <div className="flex justify-between text-[10px] text-text-muted mb-1">
            <span>Progress</span>
            <span className="data-readout">{job.progress_pct}%</span>
          </div>
          <div className="h-1 bg-bg-primary rounded-full overflow-hidden">
            <div
              className="h-full bg-amber-500 rounded-full transition-all duration-500"
              style={{ width: `${job.progress_pct}%` }}
            />
          </div>
        </div>
      )}

      <StatusBadge status={job.status} />

      <span className="data-readout text-[10px] text-text-muted w-16 text-right shrink-0">
        {new Date(job.updated_at).toLocaleTimeString()}
      </span>
    </div>
  );
}

const LOG_COLORS: Record<string, string> = {
  info: "text-signal-blue",
  warning: "text-signal-yellow",
  error: "text-signal-red",
  debug: "text-text-muted",
};

function LogLine({ entry }: { entry: LogEntry }) {
  return (
    <div className="flex gap-2 text-xs leading-relaxed font-mono">
      <span className="text-text-muted shrink-0 w-20">
        {new Date(entry.timestamp).toLocaleTimeString()}
      </span>
      <span
        className={cn(
          "shrink-0 w-12 uppercase",
          LOG_COLORS[entry.level] ?? "text-text-secondary"
        )}
      >
        {entry.level}
      </span>
      <span className="text-amber-400/60 shrink-0 w-16 truncate">
        {entry.service}
      </span>
      <span className="text-text-secondary">{entry.message}</span>
    </div>
  );
}

export function TasksPage() {
  const [logFilter, setLogFilter] = useState<string | undefined>(undefined);
  const jobs = useSimulationJobs();
  const logs = useLogs(logFilter);

  return (
    <div className="p-6 space-y-6">
      {/* Header */}
      <div>
        <h2
          className="text-2xl font-bold tracking-[0.15em] text-text-primary"
          style={{ fontFamily: "var(--font-display)" }}
        >
          TASK MANAGER
        </h2>
        <p className="text-xs text-text-muted tracking-wider mt-1">
          Simulation jobs &amp; system logs
        </p>
      </div>

      {/* Jobs */}
      <Panel
        title="Simulation Jobs"
        icon={<ListTodo className="w-4 h-4" />}
        actions={
          <span className="data-readout text-xs text-text-muted">
            {jobs.data?.length ?? 0} total
          </span>
        }
      >
        <div className="space-y-2">
          {jobs.data?.map((job) => <JobRow key={job.job_id} job={job} />) ?? (
            <div className="text-center py-8 text-text-muted text-sm">
              {jobs.isLoading
                ? "Loading jobs..."
                : jobs.isError
                  ? "Cannot fetch jobs"
                  : "No simulation jobs"}
            </div>
          )}
          {jobs.data?.length === 0 && (
            <div className="text-center py-8 text-text-muted text-sm">
              No simulation jobs yet
            </div>
          )}
        </div>
      </Panel>

      {/* Logs */}
      <Panel
        title="System Logs"
        icon={<Terminal className="w-4 h-4" />}
        actions={
          <div className="flex items-center gap-2">
            <Filter className="w-3 h-3 text-text-muted" />
            {["all", "planning", "simulation"].map((f) => (
              <button
                key={f}
                onClick={() => setLogFilter(f === "all" ? undefined : f)}
                className={cn(
                  "text-[10px] px-2 py-0.5 rounded tracking-wider uppercase transition-all",
                  (f === "all" && !logFilter) || logFilter === f
                    ? "bg-amber-500/20 text-amber-400"
                    : "text-text-muted hover:text-text-secondary"
                )}
              >
                {f}
              </button>
            ))}
          </div>
        }
      >
        <div className="max-h-80 overflow-y-auto space-y-0.5 bg-bg-primary rounded-sm p-3 border border-border-dim">
          {logs.data?.map((entry, i) => (
            <LogLine key={`${entry.timestamp}-${i}`} entry={entry} />
          )) ?? (
            <div className="text-center py-4 text-text-muted text-xs">
              {logs.isLoading ? "Loading logs..." : "No log data"}
            </div>
          )}
        </div>
      </Panel>
    </div>
  );
}
