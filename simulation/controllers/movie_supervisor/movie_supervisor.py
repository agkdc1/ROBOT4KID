"""Movie recording supervisor — captures simulation video for Gemini audit.

Sets camera viewpoint, runs simulation for a fixed duration, records movie,
then exports individual frames as PNGs for composite stitching.

Usage in .wbt:
    DEF SUPERVISOR Robot {
      controller "movie_supervisor"
      supervisor TRUE
    }
"""

import os
import sys
import math

try:
    from controller import Supervisor
except ImportError:
    Supervisor = None

TIMESTEP = 16          # ms
RECORD_DURATION = 10   # seconds of simulation to record
MOVIE_WIDTH = 1280
MOVIE_HEIGHT = 720
MOVIE_FPS = 30
MOVIE_QUALITY = 90     # JPEG quality

# Output paths
# Navigate up from controllers/movie_supervisor/ to project root
_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
_CONTROLLERS_DIR = os.path.dirname(_THIS_DIR)
_SIM_DIR = os.path.dirname(_CONTROLLERS_DIR)
PROJECT_DIR = os.path.dirname(_SIM_DIR)
OUTPUT_DIR = os.path.join(PROJECT_DIR, "simulation", "video_frames")
MOVIE_FILE = os.path.join(OUTPUT_DIR, "simulation_demo.mp4")


def setup_camera(supervisor):
    """Position the viewpoint to show both robots from above-angle."""
    viewpoint = supervisor.getFromDef("VIEWPOINT")
    if viewpoint is None:
        # Try to get the first Viewpoint node
        root = supervisor.getRoot()
        children = root.getField("children")
        for i in range(children.getCount()):
            node = children.getMFNode(i)
            if node.getTypeName() == "Viewpoint":
                viewpoint = node
                break

    if viewpoint:
        # Set camera to show both robots from above-right angle
        pos_field = viewpoint.getField("position")
        ori_field = viewpoint.getField("orientation")

        # Exact values from manually adjusted Webots GUI viewpoint
        pos_field.setSFVec3f([1.3821, -0.2938, 0.6817])
        ori_field.setSFRotation([0.3529, 0.1387, -0.9253, 3.7482])

        print(f"[movie_supervisor] Camera set from GUI-calibrated viewpoint")
    else:
        print("[movie_supervisor] WARNING: Could not find Viewpoint node")


def take_screenshots(supervisor, count=6, interval_steps=50):
    """Take periodic screenshots during simulation."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    frames = []

    for i in range(count):
        # Run simulation for interval
        for _ in range(interval_steps):
            if supervisor.step(TIMESTEP) == -1:
                return frames

        # Export screenshot
        filename = os.path.join(OUTPUT_DIR, f"sim_frame_{i:03d}.jpg")
        supervisor.exportImage(filename, MOVIE_QUALITY)
        frames.append(filename)
        t = supervisor.getTime()
        print(f"[movie_supervisor] Frame {i}: t={t:.2f}s -> {filename}")

    return frames


def record_movie(supervisor):
    """Record a movie using Webots movie API."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print(f"[movie_supervisor] Starting movie recording: {MOVIE_FILE}")
    print(f"[movie_supervisor] Duration: {RECORD_DURATION}s, {MOVIE_WIDTH}x{MOVIE_HEIGHT} @ {MOVIE_FPS}fps")

    # Start movie recording
    supervisor.movieStartRecording(
        MOVIE_FILE,
        MOVIE_WIDTH,
        MOVIE_HEIGHT,
        quality=MOVIE_QUALITY,
        codec=0,  # 0 = default codec
        acceleration=1,
        caption=False,
    )

    # Run simulation for the recording duration
    total_steps = int(RECORD_DURATION * 1000 / TIMESTEP)
    for step in range(total_steps):
        if supervisor.step(TIMESTEP) == -1:
            break
        # Progress every 2 seconds
        if step % (2000 // TIMESTEP) == 0:
            t = supervisor.getTime()
            print(f"[movie_supervisor] Recording... t={t:.1f}s")

    # Stop recording
    supervisor.movieStopRecording()

    # Wait for movie to be written
    while supervisor.movieIsReady() == False:
        supervisor.step(TIMESTEP)

    if supervisor.movieFailed():
        print("[movie_supervisor] ERROR: Movie recording failed!")
        return None

    print(f"[movie_supervisor] Movie saved: {MOVIE_FILE}")
    return MOVIE_FILE


def main():
    supervisor = Supervisor()
    print("[movie_supervisor] Starting movie recording supervisor")

    # 1. Set camera viewpoint
    setup_camera(supervisor)

    # Let scene initialize
    for _ in range(10):
        supervisor.step(TIMESTEP)

    # 2. Take screenshots at intervals (faster, always works)
    print("[movie_supervisor] Taking 6 screenshot frames...")
    frames = take_screenshots(supervisor, count=6, interval_steps=100)
    print(f"[movie_supervisor] Captured {len(frames)} frames")

    # 3. Try movie recording (may not work headless on all platforms)
    try:
        movie = record_movie(supervisor)
        if movie:
            print(f"[movie_supervisor] Movie: {movie}")
    except Exception as e:
        print(f"[movie_supervisor] Movie recording failed: {e}")
        print("[movie_supervisor] Using screenshot frames instead")

    # 4. Signal completion
    print("[movie_supervisor] DONE — frames ready for Gemini audit")

    # Keep running briefly then quit
    for _ in range(50):
        supervisor.step(TIMESTEP)


if __name__ == "__main__":
    if Supervisor is not None:
        main()
    else:
        print("Run this inside Webots, not standalone.")
