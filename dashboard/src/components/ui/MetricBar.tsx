import { cn } from "@/lib/utils";

interface MetricBarProps {
  label: string;
  value: number;
  max: number;
  unit?: string;
  colorClass?: string;
  className?: string;
}

export function MetricBar({
  label,
  value,
  max,
  unit = "",
  colorClass,
  className,
}: MetricBarProps) {
  const pct = max > 0 ? Math.min((value / max) * 100, 100) : 0;

  const barColor =
    colorClass ??
    (pct > 90
      ? "bg-signal-red"
      : pct > 70
        ? "bg-signal-orange"
        : pct > 50
          ? "bg-amber-500"
          : "bg-signal-green");

  return (
    <div className={cn("space-y-1", className)}>
      <div className="flex items-center justify-between text-xs">
        <span className="text-text-secondary uppercase tracking-wider">
          {label}
        </span>
        <span className="data-readout text-text-primary">
          {value.toFixed(1)}
          {unit && <span className="text-text-muted ml-0.5">{unit}</span>}
          <span className="text-text-muted">
            {" "}
            / {max.toFixed(1)}
            {unit}
          </span>
        </span>
      </div>
      <div className="h-1.5 bg-bg-secondary rounded-full overflow-hidden">
        <div
          className={cn("h-full rounded-full transition-all duration-700", barColor)}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
}
