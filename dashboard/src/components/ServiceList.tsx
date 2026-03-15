import { Cog, Play, Square } from "lucide-react";
import { Panel } from "@/components/ui/Panel";
import { StatusBadge } from "@/components/ui/StatusBadge";
import type { ServiceInfo } from "@/api/types";

interface ServiceListProps {
  services: ServiceInfo[];
}

export function ServiceList({ services }: ServiceListProps) {
  return (
    <Panel title="Services" icon={<Cog className="w-4 h-4" />}>
      <div className="space-y-2">
        {services.map((svc) => (
          <div
            key={svc.name}
            className="flex items-center justify-between px-3 py-2 rounded-sm bg-bg-secondary border border-border-dim"
          >
            <div className="flex items-center gap-3">
              {svc.status === "running" ? (
                <Play className="w-3 h-3 text-signal-green" />
              ) : (
                <Square className="w-3 h-3 text-signal-red" />
              )}
              <div>
                <div className="text-sm text-text-primary">
                  {svc.display_name}
                </div>
                <div className="data-readout text-[10px] text-text-muted">
                  {svc.name}
                  {svc.pid ? ` · PID ${svc.pid}` : ""}
                </div>
              </div>
            </div>
            <StatusBadge status={svc.status} />
          </div>
        ))}
        {services.length === 0 && (
          <div className="text-center py-4 text-text-muted text-sm">
            No service data
          </div>
        )}
      </div>
    </Panel>
  );
}
