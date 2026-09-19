FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Persist keys outside the container layer when /data is a mounted volume.
ENV RYUKSIGN_DB=/data/ryuksign.db

CMD uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}
