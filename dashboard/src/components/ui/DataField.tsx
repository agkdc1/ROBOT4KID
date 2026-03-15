import { cn } from "@/lib/utils";

interface DataFieldProps {
  label: string;
  value: string | number;
  unit?: string;
  className?: string;
  large?: boolean;
}

export function DataField({
  label,
  value,
  unit,
  className,
  large,
}: DataFieldProps) {
  return (
    <div className={cn("space-y-0.5", className)}>
      <div className="text-[10px] text-text-muted uppercase tracking-widest">
        {label}
      </div>
      <div
        className={cn(
          "data-readout text-text-primary",
          large ? "text-2xl font-bold" : "text-sm"
        )}
      >
        {value}
        {unit && (
          <span className="text-text-muted text-xs ml-1">{unit}</span>
        )}
      </div>
    </div>
  );
}
