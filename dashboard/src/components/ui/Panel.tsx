import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

interface PanelProps {
  title: string;
  icon?: ReactNode;
  children: ReactNode;
  className?: string;
  accent?: boolean;
  actions?: ReactNode;
}

export function Panel({
  title,
  icon,
  children,
  className,
  accent,
  actions,
}: PanelProps) {
  return (
    <div
      className={cn(
        "rounded-sm border border-border-dim bg-bg-panel overflow-hidden",
        accent && "glow-border-active",
        className
      )}
    >
      <div className="panel-header flex items-center justify-between px-4 py-2.5">
        <div className="flex items-center gap-2">
          {icon && (
            <span className="text-amber-500 opacity-80">{icon}</span>
          )}
          <h3
            className="text-sm font-semibold tracking-widest uppercase text-text-secondary"
            style={{ fontFamily: "var(--font-display)" }}
          >
            {title}
          </h3>
        </div>
        {actions && <div className="flex items-center gap-2">{actions}</div>}
      </div>
      <div className="p-4">{children}</div>
    </div>
  );
}
