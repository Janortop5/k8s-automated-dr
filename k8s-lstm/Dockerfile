############################################################
# -------- Stage 1 : Train notebook & collect model ------- #
############################################################
FROM python:3.10-slim AS trainer

WORKDIR /workspace

# 1. Install the full training stack
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir jupyter nbconvert

# 2. Copy the notebook and any helper modules it imports
COPY notebook/ ./notebook/

# 3. Execute the notebook head-less; ModelManager will write to ./models/
RUN jupyter nbconvert \
      --to notebook \
      --execute ./notebook/lstm-disaster-recovery.ipynb \
      --output executed.ipynb \
      --ExecutePreprocessor.timeout=1800

############################################################
# -------- Stage 2 : Slim runtime / inference ------------- #
############################################################
FROM python:3.10-slim AS runtime

WORKDIR /app

# 4. Install **runtime-only** dependencies (small footprint)
COPY runtime-requirements.txt .
RUN pip install --no-cache-dir -r runtime-requirements.txt

# 5. Copy the trained artefacts produced in Stage 1
COPY --from=trainer /workspace/models ./model/

