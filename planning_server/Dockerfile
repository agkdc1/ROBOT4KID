FROM python:3.13-slim

WORKDIR /app

# System deps
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends gcc && \
    rm -rf /var/lib/apt/lists/*

# Python deps
COPY planning_server/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# App code
COPY shared/ /app/shared/
COPY config/ /app/config/
COPY planning_server/ /app/planning_server/

ENV PYTHONPATH=/app
ENV PORT=8000
ENV ENVIRONMENT=cloud

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "planning_server.app.main:app", "--host", "0.0.0.0", "--port", "8000"]
