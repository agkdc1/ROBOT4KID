import { cn, getStatusDot, getStatusColor } from "@/lib/utils";

interface StatusBadgeProps {
  status: string;
  label?: string;
  pulse?: boolean;
  className?: string;
}

export function StatusBadge({
  status,
  label,
  pulse = true,
  className,
}: StatusBadgeProps) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 text-xs font-medium data-readout",
        getStatusColor(status),
        className
      )}
    >
      <span
        className={cn(
          "w-2 h-2 rounded-full",
          getStatusDot(status),
          pulse && status.toLowerCase() !== "offline" && status.toLowerCase() !== "stopped" && "status-pulse"
        )}
      />
      {label ?? status.toUpperCase()}
    </span>
  );
}
