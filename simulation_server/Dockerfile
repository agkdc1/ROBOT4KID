FROM python:3.13-slim

# Cloud Run: light mode (trimesh analysis, URDF gen, job dispatch)
# No OpenSCAD/Webots — heavy jobs go to Spot VM via Pub/Sub

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends gcc && \
    rm -rf /var/lib/apt/lists/*

COPY simulation_server/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY shared/ /app/shared/
COPY config/ /app/config/
COPY simulation_server/ /app/simulation_server/

ENV PYTHONPATH=/app
ENV PORT=8100
ENV ENVIRONMENT=cloud

EXPOSE 8100

CMD ["python", "-m", "uvicorn", "simulation_server.app.main:app", "--host", "0.0.0.0", "--port", "8100"]
