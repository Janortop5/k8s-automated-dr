# Use an official Python runtime as a parent image
FROM python:3.8-slim

# Set a working directory
WORKDIR /app

# Copy the notebook (and any helper scripts) into the container
COPY notebook/* ./

# Copy and install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Expose port for Jupyter (if you plan to run the notebook in-cluster)
EXPOSE 8888

# Default command: launch Jupyter in no-browser mode
CMD ["jupyter", "notebook", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root"]
