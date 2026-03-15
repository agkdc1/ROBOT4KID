import {
  Server,
  CheckCircle,
  XCircle,
} from "lucide-react";
import { Panel } from "@/components/ui/Panel";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { DataField } from "@/components/ui/DataField";
import { formatUptime } from "@/lib/utils";

interface ServerCardProps {
  name: string;
  port: number;
  status: string;
  version: string;
  uptime: number;
  capabilities?: Record<string, boolean>;
}

export function ServerCard({
  name,
  port,
  status,
  version,
  uptime,
  capabilities,
}: ServerCardProps) {
  return (
    <Panel
      title={name}
      icon={<Server className="w-4 h-4" />}
      accent={status === "online"}
      actions={<StatusBadge status={status} />}
    >
      <div className="grid grid-cols-3 gap-4 mb-4">
        <DataField label="Port" value={port} />
        <DataField label="Version" value={version} />
        <DataField
          label="Uptime"
          value={uptime > 0 ? formatUptime(uptime) : "—"}
        />
      </div>

      {capabilities && (
        <div className="border-t border-border-dim pt-3 mt-3">
          <div className="text-[10px] text-text-muted tracking-widest mb-2 uppercase">
            Capabilities
          </div>
          <div className="grid grid-cols-2 gap-1.5">
            {Object.entries(capabilities).map(([key, enabled]) => (
              <div
                key={key}
                className="flex items-center gap-1.5 text-xs"
              >
                {enabled ? (
                  <CheckCircle className="w-3 h-3 text-signal-green" />
                ) : (
                  <XCircle className="w-3 h-3 text-text-muted" />
                )}
                <span className={enabled ? "text-text-primary" : "text-text-muted"}>
                  {key.replace(/_/g, " ")}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </Panel>
  );
}
