import { useCallback, useEffect, useRef, useState } from "react";
import {
  Monitor,
  Play,
  Square,
  Wifi,
  WifiOff,
  Maximize2,
  Minimize2,
  RefreshCw,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Panel } from "@/components/ui/Panel";
import { StatusBadge } from "@/components/ui/StatusBadge";

type ConnectionStatus = "idle" | "connecting" | "connected" | "disconnected" | "error";

export interface SimulationViewerProps {
  jobId: string;
  wsUrl?: string;
  streamHttpUrl?: string;
  onStart?: () => void;
  onStop?: () => void;
  isRunning?: boolean;
}

function statusToLabel(status: ConnectionStatus): string {
  switch (status) {
    case "idle":
      return "STANDBY";
    case "connecting":
      return "CONNECTING";
    case "connected":
      return "ONLINE";
    case "disconnected":
      return "OFFLINE";
    case "error":
      return "ERROR";
  }
}

function statusToBadge(status: ConnectionStatus): string {
  switch (status) {
    case "connected":
      return "online";
    case "connecting":
      return "warning";
    case "disconnected":
    case "error":
      return "offline";
    default:
      return "unknown";
  }
}

export function SimulationViewer({
  jobId,
  streamHttpUrl,
  onStart,
  onStop,
  isRunning = false,
}: SimulationViewerProps) {
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const [connectionStatus, setConnectionStatus] = useState<ConnectionStatus>("idle");
  const [isFullscreen, setIsFullscreen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  // Update connection status based on running state
  useEffect(() => {
    if (isRunning && streamHttpUrl) {
      setConnectionStatus("connecting");
      // Give the stream a moment to initialize, then mark connected
      const timer = setTimeout(() => setConnectionStatus("connected"), 2000);
      return () => clearTimeout(timer);
    } else if (!isRunning) {
      setConnectionStatus("idle");
    }
  }, [isRunning, streamHttpUrl]);

  // Listen for iframe load/error
  const handleIframeLoad = useCallback(() => {
    if (isRunning) {
      setConnectionStatus("connected");
    }
  }, [isRunning]);

  const handleIframeError = useCallback(() => {
    setConnectionStatus("error");
  }, []);

  // Fullscreen toggle
  const toggleFullscreen = useCallback(() => {
    if (!containerRef.current) return;
    if (!document.fullscreenElement) {
      containerRef.current.requestFullscreen().then(() => setIsFullscreen(true));
    } else {
      document.exitFullscreen().then(() => setIsFullscreen(false));
    }
  }, []);

  useEffect(() => {
    const handler = () => setIsFullscreen(!!document.fullscreenElement);
    document.addEventListener("fullscreenchange", handler);
    return () => document.removeEventListener("fullscreenchange", handler);
  }, []);

  const reloadIframe = useCallback(() => {
    if (iframeRef.current && streamHttpUrl) {
      setConnectionStatus("connecting");
      iframeRef.current.src = streamHttpUrl;
    }
  }, [streamHttpUrl]);

  return (
    <Panel
      title="Simulation Feed"
      icon={<Monitor className="w-3.5 h-3.5" />}
      className="flex flex-col"
      actions={
        <div className="flex items-center gap-3">
          <StatusBadge
            status={statusToBadge(connectionStatus)}
            label={statusToLabel(connectionStatus)}
            pulse={connectionStatus === "connecting"}
          />
          <div className="flex items-center gap-1">
            {isRunning && streamHttpUrl && (
              <button
                onClick={reloadIframe}
                className="p-1.5 rounded-sm text-text-muted hover:text-cyan-400 hover:bg-cyan-500/10 transition-colors"
                title="Reload stream"
              >
                <RefreshCw className="w-3.5 h-3.5" />
              </button>
            )}
            <button
              onClick={toggleFullscreen}
              className="p-1.5 rounded-sm text-text-muted hover:text-cyan-400 hover:bg-cyan-500/10 transition-colors"
              title={isFullscreen ? "Exit fullscreen" : "Fullscreen"}
            >
              {isFullscreen ? (
                <Minimize2 className="w-3.5 h-3.5" />
              ) : (
                <Maximize2 className="w-3.5 h-3.5" />
              )}
            </button>
          </div>
        </div>
      }
    >
      <div ref={containerRef} className="flex flex-col gap-4">
        {/* Viewport */}
        <div
          className={cn(
            "relative w-full bg-black/60 rounded-sm border border-border-dim overflow-hidden",
            isFullscreen ? "h-full" : "aspect-video"
          )}
        >
          {isRunning && streamHttpUrl ? (
            <>
              <iframe
                ref={iframeRef}
                src={streamHttpUrl}
                className="absolute inset-0 w-full h-full border-0"
                allow="autoplay; fullscreen"
                onLoad={handleIframeLoad}
                onError={handleIframeError}
              />
              {connectionStatus === "connecting" && (
                <div className="absolute inset-0 flex items-center justify-center bg-black/80 z-10">
                  <div className="text-center">
                    <Wifi className="w-8 h-8 text-cyan-500 mx-auto mb-3 animate-pulse" />
                    <div
                      className="text-sm text-cyan-400 tracking-widest"
                      style={{ fontFamily: "var(--font-display)" }}
                    >
                      ESTABLISHING LINK...
                    </div>
                  </div>
                </div>
              )}
            </>
          ) : (
            <div className="absolute inset-0 flex items-center justify-center">
              <div className="text-center">
                <WifiOff className="w-10 h-10 text-text-muted mx-auto mb-3 opacity-30" />
                <div
                  className="text-sm text-text-muted tracking-widest mb-1"
                  style={{ fontFamily: "var(--font-display)" }}
                >
                  NO SIGNAL
                </div>
                <div className="text-xs text-text-muted opacity-60">
                  Start simulation to establish feed
                </div>
              </div>
            </div>
          )}

          {/* HUD overlay corners */}
          {isRunning && connectionStatus === "connected" && (
            <>
              <div className="absolute top-2 left-2 w-6 h-6 border-t-2 border-l-2 border-cyan-500/50 pointer-events-none" />
              <div className="absolute top-2 right-2 w-6 h-6 border-t-2 border-r-2 border-cyan-500/50 pointer-events-none" />
              <div className="absolute bottom-2 left-2 w-6 h-6 border-b-2 border-l-2 border-cyan-500/50 pointer-events-none" />
              <div className="absolute bottom-2 right-2 w-6 h-6 border-b-2 border-r-2 border-cyan-500/50 pointer-events-none" />
              <div className="absolute top-2 left-10 text-[10px] text-cyan-500/70 tracking-widest data-readout pointer-events-none">
                JOB: {jobId}
              </div>
              <div className="absolute top-2 right-10 text-[10px] text-cyan-500/70 tracking-widest data-readout pointer-events-none">
                LIVE
              </div>
            </>
          )}
        </div>

        {/* Controls */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            {!isRunning ? (
              <button
                onClick={onStart}
                className={cn(
                  "flex items-center gap-2 px-4 py-2 rounded-sm text-xs font-semibold tracking-widest uppercase transition-all",
                  "bg-signal-green/10 text-signal-green border border-signal-green/30",
                  "hover:bg-signal-green/20 hover:border-signal-green/50"
                )}
                style={{ fontFamily: "var(--font-display)" }}
              >
                <Play className="w-3.5 h-3.5" />
                START
              </button>
            ) : (
              <button
                onClick={onStop}
                className={cn(
                  "flex items-center gap-2 px-4 py-2 rounded-sm text-xs font-semibold tracking-widest uppercase transition-all",
                  "bg-signal-red/10 text-signal-red border border-signal-red/30",
                  "hover:bg-signal-red/20 hover:border-signal-red/50"
                )}
                style={{ fontFamily: "var(--font-display)" }}
              >
                <Square className="w-3.5 h-3.5" />
                STOP
              </button>
            )}
          </div>

          <div className="text-[10px] text-text-muted tracking-wider data-readout">
            {streamHttpUrl ? streamHttpUrl : "No stream URL"}
          </div>
        </div>
      </div>
    </Panel>
  );
}
