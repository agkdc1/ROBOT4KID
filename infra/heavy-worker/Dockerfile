FROM python:3.13-slim

# Heavy worker: OpenSCAD rendering, STL analysis, batch processing
# Runs as Cloud Run Job triggered by Pub/Sub

WORKDIR /app

# System deps: OpenSCAD + Xvfb for headless rendering
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
        openscad xvfb xauth gcc && \
    rm -rf /var/lib/apt/lists/*

# Python deps
COPY infra/heavy-worker/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# App code
COPY infra/spot-vm/job_runner.py /app/job_runner.py
COPY shared/ /app/shared/
COPY config/ /app/config/

ENV PYTHONPATH=/app

# Cloud Run Job: process one job from Pub/Sub then exit
CMD ["python", "job_runner.py", "--single"]
