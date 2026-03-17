import { NavLink, Outlet } from "react-router-dom";
import {
  Activity,
  LayoutGrid,
  ListTodo,
  Cpu,
  Zap,
  Radio,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { usePlanningHealth, useSimulationHealth } from "@/hooks/useQueries";
import { StatusBadge } from "@/components/ui/StatusBadge";

const NAV_ITEMS = [
  { to: "/", label: "INFRA", icon: Activity },
  { to: "/tasks", label: "TASKS", icon: ListTodo },
  { to: "/projects", label: "MODELS", icon: LayoutGrid },
  { to: "/simulation", label: "SIM", icon: Radio },
] as const;

export function Layout() {
  const planning = usePlanningHealth();
  const simulation = useSimulationHealth();

  return (
    <div className="flex h-screen scanlines">
      {/* Sidebar */}
      <nav className="w-56 shrink-0 bg-bg-secondary border-r border-border-dim flex flex-col">
        {/* Logo */}
        <div className="p-5 border-b border-border-dim">
          <div className="flex items-center gap-2">
            <Zap className="w-5 h-5 text-amber-500" />
            <h1
              className="text-lg font-bold tracking-[0.2em] text-amber-400"
              style={{ fontFamily: "var(--font-display)" }}
            >
              NL2BOT
            </h1>
          </div>
          <div className="text-[10px] text-text-muted tracking-[0.3em] mt-0.5 uppercase">
            Command Center
          </div>
        </div>

        {/* Nav links */}
        <div className="flex-1 py-4 space-y-1 px-3">
          {NAV_ITEMS.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              end={to === "/"}
              className={({ isActive }) =>
                cn(
                  "flex items-center gap-3 px-3 py-2.5 rounded-sm text-sm tracking-widest transition-all",
                  isActive
                    ? "bg-amber-500/10 text-amber-400 border border-amber-500/20"
                    : "text-text-secondary hover:bg-bg-hover hover:text-text-primary border border-transparent"
                )
              }
              style={{ fontFamily: "var(--font-display)" }}
            >
              <Icon className="w-4 h-4" />
              {label}
            </NavLink>
          ))}
        </div>

        {/* Status footer */}
        <div className="border-t border-border-dim p-4 space-y-2.5">
          <div className="flex items-center justify-between">
            <span className="text-[10px] text-text-muted tracking-widest flex items-center gap-1.5">
              <Cpu className="w-3 h-3" />
              PLANNING
            </span>
            <StatusBadge
              status={planning.data ? "online" : planning.isError ? "offline" : "unknown"}
              pulse
            />
          </div>
          <div className="flex items-center justify-between">
            <span className="text-[10px] text-text-muted tracking-widest flex items-center gap-1.5">
              <Cpu className="w-3 h-3" />
              SIMULATION
            </span>
            <StatusBadge
              status={simulation.data ? "online" : simulation.isError ? "offline" : "unknown"}
              pulse
            />
          </div>
        </div>
      </nav>

      {/* Main content */}
      <main className="flex-1 overflow-auto bg-bg-primary">
        <Outlet />
      </main>
    </div>
  );
}
