import {
  LayoutGrid,
  Box,
  Train,
  Shield,
  Calendar,
  Layers,
  PlayCircle,
} from "lucide-react";
import { Panel } from "@/components/ui/Panel";
import { StatusBadge } from "@/components/ui/StatusBadge";
import { useProjects } from "@/hooks/useQueries";
import { cn } from "@/lib/utils";
import type { ProjectInfo } from "@/api/types";

const MODEL_ICONS = {
  tank: Shield,
  train: Train,
};

const MODEL_COLORS = {
  tank: {
    bg: "bg-signal-green/5",
    border: "border-signal-green/20",
    icon: "text-signal-green",
    badge: "bg-signal-green/10 text-signal-green",
  },
  train: {
    bg: "bg-signal-blue/5",
    border: "border-signal-blue/20",
    icon: "text-signal-blue",
    badge: "bg-signal-blue/10 text-signal-blue",
  },
};

function ProjectCard({ project }: { project: ProjectInfo }) {
  const colors = MODEL_COLORS[project.model_type] ?? MODEL_COLORS.tank;
  const Icon = MODEL_ICONS[project.model_type] ?? Box;

  return (
    <div
      className={cn(
        "rounded-sm border p-4 transition-all hover:bg-bg-hover cursor-pointer group",
        colors.border,
        colors.bg
      )}
    >
      {/* Header */}
      <div className="flex items-start justify-between mb-3">
        <div className="flex items-center gap-2.5">
          <div
            className={cn(
              "w-9 h-9 rounded-sm flex items-center justify-center",
              "bg-bg-secondary border border-border-dim"
            )}
          >
            <Icon className={cn("w-5 h-5", colors.icon)} />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-text-primary group-hover:text-amber-400 transition-colors">
              {project.name}
            </h3>
            <span
              className={cn(
                "text-[10px] px-1.5 py-0.5 rounded uppercase tracking-wider inline-block mt-0.5",
                colors.badge
              )}
            >
              {project.model_type}
            </span>
          </div>
        </div>
        <StatusBadge status={project.status} pulse={false} />
      </div>

      {/* Description */}
      <p className="text-xs text-text-secondary line-clamp-2 mb-3">
        {project.description}
      </p>

      {/* Footer stats */}
      <div className="flex items-center justify-between pt-3 border-t border-border-dim">
        <div className="flex items-center gap-3 text-[10px] text-text-muted">
          <span className="flex items-center gap-1">
            <Layers className="w-3 h-3" />
            {project.parts_count} parts
          </span>
          <span className="flex items-center gap-1">
            <Calendar className="w-3 h-3" />
            {new Date(project.updated_at).toLocaleDateString()}
          </span>
        </div>
        {project.last_simulation && (
          <span className="flex items-center gap-1 text-[10px] text-amber-500/70">
            <PlayCircle className="w-3 h-3" />
            Simulated
          </span>
        )}
      </div>
    </div>
  );
}

export function ProjectsPage() {
  const { data: projects, isLoading, isError } = useProjects();

  return (
    <div className="p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2
            className="text-2xl font-bold tracking-[0.15em] text-text-primary"
            style={{ fontFamily: "var(--font-display)" }}
          >
            MODEL REGISTRY
          </h2>
          <p className="text-xs text-text-muted tracking-wider mt-1">
            Robot projects &amp; simulation status
          </p>
        </div>
        <div className="flex items-center gap-3">
          {Object.entries(MODEL_COLORS).map(([type, colors]) => {
            const Icon = MODEL_ICONS[type as keyof typeof MODEL_ICONS];
            const count =
              projects?.filter((p) => p.model_type === type).length ?? 0;
            return (
              <div
                key={type}
                className="flex items-center gap-1.5 text-xs text-text-secondary"
              >
                <Icon className={cn("w-3.5 h-3.5", colors.icon)} />
                <span className="data-readout">{count}</span>
                <span className="uppercase tracking-wider">{type}</span>
              </div>
            );
          })}
        </div>
      </div>

      <Panel
        title="Projects"
        icon={<LayoutGrid className="w-4 h-4" />}
        actions={
          <span className="data-readout text-xs text-text-muted">
            {projects?.length ?? 0} models
          </span>
        }
      >
        {isLoading ? (
          <div className="text-center py-12 text-amber-500 data-readout text-sm animate-pulse tracking-widest">
            LOADING REGISTRY...
          </div>
        ) : isError ? (
          <div className="text-center py-12 text-signal-red text-sm">
            Cannot fetch projects
          </div>
        ) : projects && projects.length > 0 ? (
          <div className="grid grid-cols-2 gap-4">
            {projects.map((project) => (
              <ProjectCard key={project.id} project={project} />
            ))}
          </div>
        ) : (
          <div className="text-center py-12 text-text-muted text-sm">
            No projects found. Create one via the Planning Server.
          </div>
        )}
      </Panel>
    </div>
  );
}
