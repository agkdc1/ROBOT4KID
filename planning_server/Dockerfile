FROM python:3.11-slim

WORKDIR /app

# Install shared schemas
COPY shared/ /app/shared/
RUN pip install /app/shared/

# Install planning server dependencies
COPY planning_server/requirements.txt /app/planning_server/
RUN pip install -r /app/planning_server/requirements.txt

# Copy planning server code
COPY planning_server/ /app/planning_server/

EXPOSE 8000
CMD ["python", "-m", "uvicorn", "planning_server.app.main:app", "--host", "0.0.0.0", "--port", "8000"]
