from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import numpy as np
import tensorflow as tf
from tensorflow import keras
import logging
import os
import pickle
from typing import List
import uvicorn

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="LSTM Model API",
    description="API for serving LSTM model predictions",
    version="1.0.0"
)

# Global variable to store the model
model = None
scaler_features, scaler_targets = None, None


class PredictionRequest(BaseModel):
    data: List[List[float]]  # 2D array for sequence data


class PredictionResponse(BaseModel):
    predictions: dict
    status: str


def disaster_aware_loss(threshold=0.7, disaster_penalty_weight=2.0):
    """Custom loss function that penalizes disaster threshold breaches more"""
    def loss_fn(y_true, y_pred):
        # Standard MSE loss
        loss = tf.keras.losses.MeanSquaredError(
            reduction='sum_over_batch_size',
            name='mean_squared_error'
        )
        mse_loss = loss.call(y_true, y_pred)

        # Additional penalty for predictions that miss disaster conditions
        disaster_mask = tf.cast(y_true > threshold, tf.float32)
        disaster_errors = tf.abs(y_pred - y_true) * disaster_mask
        disaster_penalty = tf.reduce_mean(
            disaster_errors) * disaster_penalty_weight

        return mse_loss + disaster_penalty

    return loss_fn


def load_scalers():
    """Load the fitted scalers"""
    global scaler_features, scaler_targets
    path = "./scalers"
    with open(f"{path}/feature_scaler.pkl", 'rb') as f:
        scaler_features = pickle.load(f)
    with open(f"{path}/target_scaler.pkl", 'rb') as f:
        scaler_targets = pickle.load(f)
    print(f"Scalers loaded from {path}")

    return scaler_features, scaler_targets


def load_model():
    """
    Load model from different formats

    Args:
        model_name: Name of the model files
        load_format: h5'
    """
    try:
        global model
        model_path = os.getenv("MODEL_PATH", "./models/lstm_model.h5")
        model = keras.models.load_model(
            model_path,
            custom_objects={'loss_fn': disaster_aware_loss()}
        )
        print(f"✓ HDF5 model loaded from: {model_path}")

    except Exception:
        raise ValueError("Unable to load model")
    return model


@app.on_event("startup")
async def startup_event():
    """Load model on startup"""
    load_model()
    load_scalers()


@app.get("/")
async def root():
    """Health check endpoint"""
    return {"message": "LSTM Model API is running", "status": "healthy"}


@app.get("/health")
async def health_check():
    """Health check endpoint for Kubernetes"""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    return {"status": "healthy", "model_loaded": True}


@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    """Make predictions using the LSTM model"""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    try:
        # Convert input data to numpy array
        input_data = np.array(request.data)

        # Reshape if necessary (assuming input needs to be 3D for LSTM)
        if len(input_data.shape) == 2:
            input_data = np.expand_dims(input_data, axis=0)

        x_reshaped = input_data.reshape(-1, input_data.shape[-1])
        x_reshaped_scaled = scaler_features.transform(
            x_reshaped).reshape(input_data.shape)

        logger.info(f"Input shape: {input_data.shape}")

        # Make prediction
        predictions = model.predict(x_reshaped_scaled)
        predictions = predictions.reshape(-1, predictions.shape[-1])

        # Inverse transform the predictions
        predictions = scaler_targets.inverse_transform(predictions)
        cpu_usage, mem_usage = predictions[0], predictions[1]
        predictions = {"cpu_usage": cpu_usage, "mem_usage": mem_usage}

        # Convert predictions to list
        # if len(predictions.shape) > 1:
        #     pred_list = predictions.flatten().tolist()
        # else:
        #     pred_list = predictions.tolist()

        logger.info(f"Predictions: {predictions}")

        return PredictionResponse(
            predictions=predictions,
            status="success"
        )

    except Exception as e:
        logger.error(f"Error during prediction: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Prediction error: {str(e)}")


@app.get("/model/info")
async def model_info():
    """Get model information"""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    try:
        return {
            "input_shape": str(model.input_shape),
            "output_shape": str(model.output_shape),
            "model_type": "LSTM",
            "layers": len(model.layers)
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error getting model info: {
                str(e)}")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
1
