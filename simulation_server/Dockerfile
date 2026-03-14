FROM python:3.11-slim

# Install OpenSCAD and Xvfb for headless rendering
RUN apt-get update && apt-get install -y --no-install-recommends \
    openscad xvfb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install shared schemas
COPY shared/ /app/shared/
RUN pip install /app/shared/

# Install simulation server dependencies
COPY simulation_server/requirements.txt /app/simulation_server/
RUN pip install -r /app/simulation_server/requirements.txt

# Copy simulation server code
COPY simulation_server/ /app/simulation_server/

EXPOSE 8100
CMD ["python", "-m", "uvicorn", "simulation_server.app.main:app", "--host", "0.0.0.0", "--port", "8100"]
