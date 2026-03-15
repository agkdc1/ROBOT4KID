import {
  Activity,
  Cpu,
  HardDrive,
  MemoryStick,
  Clock,
} from "lucide-react";
import { Panel } from "@/components/ui/Panel";
import { MetricBar } from "@/components/ui/MetricBar";
import { DataField } from "@/components/ui/DataField";
import { ServerCard } from "@/components/ServerCard";
import { GPUMonitor } from "@/components/GPUMonitor";
import { ServiceList } from "@/components/ServiceList";
import { useDashboard } from "@/hooks/useQueries";
import { formatUptime } from "@/lib/utils";

export function InfrastructurePage() {
  const { data, isLoading, isError } = useDashboard();

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-amber-500 data-readout text-sm tracking-widest animate-pulse">
          INITIALIZING SYSTEMS...
        </div>
      </div>
    );
  }

  if (isError || !data) {
    return (
      <div className="p-6">
        <div className="text-center py-16">
          <Activity className="w-12 h-12 text-signal-red mx-auto mb-4 opacity-50" />
          <h2
            className="text-xl text-text-secondary tracking-widest mb-2"
            style={{ fontFamily: "var(--font-display)" }}
          >
            CONNECTION LOST
          </h2>
          <p className="text-sm text-text-muted">
            Cannot reach Planning Server at port 8000
          </p>
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
            INFRASTRUCTURE
          </h2>
          <p className="text-xs text-text-muted tracking-wider mt-1">
            Real-time system monitoring
          </p>
        </div>
        <div className="data-readout text-xs text-text-muted">
          <Clock className="w-3 h-3 inline mr-1" />
          {new Date().toLocaleTimeString()}
        </div>
      </div>

      {/* System overview strip */}
      <div className="grid grid-cols-4 gap-4">
        <Panel title="CPU" icon={<Cpu className="w-3.5 h-3.5" />}>
          <DataField label="Usage" value={`${data.system.cpu_pct.toFixed(1)}%`} large />
        </Panel>
        <Panel title="RAM" icon={<MemoryStick className="w-3.5 h-3.5" />}>
          <MetricBar
            label="Used"
            value={data.system.ram_used_mb}
            max={data.system.ram_total_mb}
            unit="MB"
          />
        </Panel>
        <Panel title="Disk" icon={<HardDrive className="w-3.5 h-3.5" />}>
          <MetricBar
            label="Used"
            value={data.system.disk_used_gb}
            max={data.system.disk_total_gb}
            unit="GB"
          />
        </Panel>
        <Panel title="Uptime" icon={<Clock className="w-3.5 h-3.5" />}>
          <DataField
            label="System"
            value={formatUptime(data.system.uptime_seconds)}
            large
          />
        </Panel>
      </div>

      {/* GPU + Servers */}
      <div className="grid grid-cols-2 gap-6">
        <GPUMonitor gpu={data.gpu} />
        <div className="space-y-4">
          {data.servers.map((srv) => (
            <ServerCard
              key={srv.name}
              name={srv.name}
              port={srv.port}
              status={srv.status}
              version={srv.version}
              uptime={srv.uptime_seconds}
              capabilities={srv.capabilities as Record<string, boolean> | undefined}
            />
          ))}
        </div>
      </div>

      {/* Services */}
      <ServiceList services={data.services} />
    </div>
  );
}
