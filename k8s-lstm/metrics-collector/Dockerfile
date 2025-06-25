# Use Python 3.9 slim image
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user for security
RUN useradd -m -u 1001 collector && chown -R collector:collector /app
USER collector

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD python -c "import requests; requests.get('${PROMETHEUS_URL:-http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090}/api/v1/query?query=up', timeout=5)" || exit 1

# Run the application
CMD ["python", "prometheus_collector.py"]

