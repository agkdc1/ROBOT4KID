#!/bin/bash
# NL2Bot — GPU Setup for WSL2 (CUDA + PyTorch)
# Run inside WSL2 after setup_ubuntu.sh

set -e

echo "=== NL2Bot GPU Setup ==="

# Check if NVIDIA driver is accessible
if ! command -v nvidia-smi &> /dev/null; then
    echo "ERROR: nvidia-smi not found. Make sure NVIDIA Game Ready/Studio driver is installed on Windows."
    echo "WSL2 uses the Windows driver — do NOT install a Linux NVIDIA driver."
    exit 1
fi

echo "GPU detected:"
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader

# Install CUDA toolkit (WSL2 version)
if ! command -v nvcc &> /dev/null; then
    echo "Installing CUDA toolkit..."
    wget -q https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    rm cuda-keyring_1.1-1_all.deb
    sudo apt-get update
    sudo apt-get install -y cuda-toolkit
fi

# Install PyTorch with CUDA in simulation server venv
cd "$(dirname "$0")/.."
echo "Installing PyTorch with CUDA support..."
simulation_server/.venv/bin/pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121

# Verify
echo "=== Verification ==="
simulation_server/.venv/bin/python -c "
import torch
print(f'PyTorch version: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'CUDA device: {torch.cuda.get_device_name(0)}')
    print(f'CUDA memory: {torch.cuda.get_device_properties(0).total_mem / 1024**3:.1f} GB')
"

echo "=== GPU setup complete ==="
