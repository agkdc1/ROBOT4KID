import { Gauge } from "lucide-react";
import { Panel } from "@/components/ui/Panel";
import { MetricBar } from "@/components/ui/MetricBar";
import { DataField } from "@/components/ui/DataField";
import type { GPUStatus } from "@/api/types";

interface GPUMonitorProps {
  gpu: GPUStatus | null;
}

export function GPUMonitor({ gpu }: GPUMonitorProps) {
  if (!gpu) {
    return (
      <Panel title="GPU" icon={<Gauge className="w-4 h-4" />}>
        <div className="text-center py-8 text-text-muted text-sm">
          No GPU data available
        </div>
      </Panel>
    );
  }

  return (
    <Panel title="GPU" icon={<Gauge className="w-4 h-4" />} accent>
      <div className="flex items-center justify-between mb-4">
        <span
          className="text-base font-semibold text-text-primary"
          style={{ fontFamily: "var(--font-display)" }}
        >
          {gpu.name}
        </span>
        <span className="data-readout text-xs text-text-muted">
          Driver {gpu.driver_version}
        </span>
      </div>

      <div className="space-y-3 mb-4">
        <MetricBar
          label="GPU Load"
          value={gpu.utilization_pct}
          max={100}
          unit="%"
        />
        <MetricBar
          label="VRAM"
          value={gpu.memory_used_mb}
          max={gpu.memory_total_mb}
          unit="MB"
        />
        <MetricBar
          label="Power"
          value={gpu.power_draw_w}
          max={gpu.power_limit_w}
          unit="W"
        />
      </div>

      <div className="grid grid-cols-3 gap-3 pt-3 border-t border-border-dim">
        <DataField
          label="Temp"
          value={`${gpu.temperature_c}°C`}
        />
        <DataField
          label="Fan"
          value={`${gpu.fan_speed_pct}%`}
        />
        <DataField
          label="Power"
          value={`${gpu.power_draw_w}W`}
        />
      </div>
    </Panel>
  );
}
