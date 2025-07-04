############################################################
# -------- Stage 1 : Train notebook & collect model ------- #
############################################################
FROM python:3.11-slim AS trainer

WORKDIR /app

# 1. Copy the notebook and any helper modules it imports
COPY notebook/ .

# 2. Install the full training stack
# Install pip-tools, compile, then install
RUN pip install --upgrade pip setuptools wheel pip-tools && \
    pip-compile requirements.in --output-file=requirements.txt && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir jupyter nbconvert ipykernel


# 3. Execute the notebook head-less; ModelManager will write to ./models/
RUN jupyter nbconvert \
      --to notebook \
      --execute ./lstm-disaster-recovery.ipynb \
      --output executed.ipynb \
      --ExecutePreprocessor.timeout=1800 \
      --ExecutePreprocessor.kernel_name=python3

############################################################
# -------- Stage 2 : Build App ------------- #
############################################################
FROM python:3.11-slim AS builder

# Install system dependencies needed for building
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY deployment/ .

# Install packages with memory-efficient options
RUN pip install --user --no-cache-dir -r requirements.txt

############################################################
# -------- Stage 3 : Slim runtime / inference ------------- #
############################################################
FROM python:3.11-slim AS runtime

# Install only runtime dependencies
RUN apt-get update && apt-get install -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the trained artefacts produced in Stage 1
COPY --from=trainer /app/models ./models/
COPY --from=trainer /app/scalers ./scalers/
COPY --from=builder /root/.local /root/.local

# Make sure scripts in .local are usable
ENV PATH=/root/.local/bin:$PATH

COPY deployment/ .

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
