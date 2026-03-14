#!/bin/bash
# NL2Bot — Ubuntu/WSL2 Setup Script
# Run inside WSL2 Ubuntu

set -e

echo "=== NL2Bot Ubuntu Setup ==="

# Update system
sudo apt update && sudo apt upgrade -y

# Core tools
sudo apt install -y \
    git curl wget build-essential \
    python3.11 python3.11-venv python3.11-dev python3-pip \
    openscad xvfb \
    sqlite3

# Node.js 20 LTS (for Three.js tooling if needed)
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# Create Python virtual environments
echo "=== Setting up Python venvs ==="

cd "$(dirname "$0")/.."

# Shared schemas
if [ ! -d "shared/.venv" ]; then
    python3.11 -m venv shared/.venv
fi

# Planning server
if [ ! -d "planning_server/.venv" ]; then
    python3.11 -m venv planning_server/.venv
    planning_server/.venv/bin/pip install --upgrade pip
    planning_server/.venv/bin/pip install -r planning_server/requirements.txt
    planning_server/.venv/bin/pip install -e shared/
fi

# Simulation server
if [ ! -d "simulation_server/.venv" ]; then
    python3.11 -m venv simulation_server/.venv
    simulation_server/.venv/bin/pip install --upgrade pip
    simulation_server/.venv/bin/pip install -r simulation_server/requirements.txt
    simulation_server/.venv/bin/pip install -e shared/
fi

echo "=== Setup complete ==="
echo "Planning server:    cd planning_server && .venv/bin/python -m uvicorn app.main:app --port 8000 --reload"
echo "Simulation server:  cd simulation_server && .venv/bin/python -m uvicorn app.main:app --port 8100 --reload"
