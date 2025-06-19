# Kubernetes LSTM Disaster Recovery System Notebook

## Overview

This Jupyter notebook implements a proof-of-concept for an automated disaster recovery system for Kubernetes clusters using Long Short-Term Memory (LSTM) neural networks. The notebook covers:

1. **Data Loading and Preprocessing**: Loading the Kubernetes performance metrics dataset, cleaning timestamps, handling missing values, resampling time-series data, and scaling features and targets.
2. **LSTM Model Architecture**: Defining and instantiating an LSTM-based regression model to predict CPU and memory usage at the pod level.
3. **Model Training and Evaluation**: (Section in notebook) Training the LSTM on historical metrics, visualizing loss curves, and evaluating prediction accuracy.
4. **Disaster Prediction and Alerting System**: Generating alerts based on model predictions exceeding predefined thresholds and simulating recovery actions.

## Repository Structure

```
├── lstm-disaster-recovery.ipynb    # Main Jupyter notebook
├── data/                           # Folder for raw and processed datasets
├── requirements.txt                # Python dependencies
└── README.md                       # This file
```

---

## 🛠️ Prerequisites

* **Python 3.11**  
* **Conda** (optional, but recommended on macOS)  
* **Git** (to clone the repo)

---

## Dependencies

This notebook requires the following Python libraries:

* Python 3.11
* pandas>=1.3.0
* numpy>=1.21.0
* scikit-learn>=1.0.0
* matplotlib>=3.4.0
* notebook>=6.5.0
* seaborn>=0.13.2
* tensorflow==2.15.0

### Option A: Conda (recommended)

1. Create & activate:
   ```bash
   conda env create -f environment.yml
   conda activate k8s-lstm
   ```

2. Register the env as Jupyter Kernel:
    ```
    pip install ipykernel
    python -m ipykernel install --user \
        --name k8s-lstm --display-name "Python (fyp)"
    ```

3. If you update requirements.txt, sync with:
    ```bash
    Edit
    pip install -r notebook/requirements.txt
    ```

### Option B: Pip only
1. Create a venv and activate it:
    ```bash
    python3.11 -m venv .venv
    source .venv/bin/activate
    ```

2. Install dependencies:

    ```bash
    pip install --upgrade pip
    pip install -r notebook/requirements.txt
    ```

3. (Optional) Register as a kernel:
```bash
pip install ipykernel
python -m ipykernel install --user \
    --name k8s-lstm --display-name "Python (fyp)"
```

## Dataset

The notebook expects a CSV file containing Kubernetes performance metrics with at least the following columns:

* `timestamp`: DateTime string for metric recording times.
* `pod_name`: Identifier for each pod.
* `cpu_usage`: CPU usage metric (e.g., cores).
* `memory_usage`: Memory usage metric (e.g., MiB).

By default, the notebook uses the Kaggle dataset path:

```python
"/data/kaggle/input/kubernetes_performance_metrics_dataset.csv"
```
and secondly,
```python
"/data/cluster/"
```

Adjust the `csv_path` variable in the DataProcessor instantiation as needed.

## Running the Notebook
1. Change into the notebook folder so that os.getcwd() points at …/k8s-lstm/notebook:
    ```bash
    cd k8s-lstm/notebook
    ```

2. Launch Jupyter:
    ```bash
    jupyter notebook
    ```

3. Select the Python (fyp) (or your Conda/env name) kernel.

4. Run All cells top-to-bottom (ModelManager is defined first).

5. **Run all cells** to preprocess data, train the model, evaluate performance, and simulate disaster alerts.

## 💾 Model Saving & Loading

After “Run All” you’ll see:

```
models/
├─ kubernetes_lstm_disaster_recovery.h5
└─ kubernetes_lstm_disaster_recovery_architecture.json
```

## Contributing
Contributions and suggestions are welcome! Please open an issue or submit a pull request.

## License
This project is released under the MIT License. See [LICENSE](LICENSE) for details.

