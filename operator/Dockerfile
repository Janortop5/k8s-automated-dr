# Use a slim Python base
FROM python:3.9-slim

# Install OS-level deps (if needed)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      gcc \
      libssl-dev \
      && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy operator code
COPY dr_operator.py .

# Expose any ports if your operator serves metrics or health probes
# (Uncomment if required)
# EXPOSE 8080

# Run the operator via Kopf
ENTRYPOINT ["kopf", "run", "--verbose", "dr_operator.py"]
