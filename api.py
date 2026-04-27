from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib
import os
import pandas as pd
import warnings

warnings.filterwarnings("ignore", category=UserWarning)

app = Flask(__name__)
CORS(app)

# Load the Random Forest model
MODEL_PATH = "dosha_rf_model.pkl"
try:
    model = joblib.load(MODEL_PATH)
    print(f"Model loaded successfully. Classes: {model.classes_}")
except Exception as e:
    print(f"Error loading model: {e}")
    model = None

@app.route('/predict', methods=['POST'])
def predict():
    if model is None:
        return jsonify({"error": "Model is not loaded."}), 500
        
    data = request.json
    if not data:
        return jsonify({"error": "No input data provided"}), 400
        
    try:
        hr = float(data.get('heart_rate', 75))
        spo2 = float(data.get('spo2', 98))
        temp = float(data.get('temperature_c', 36.6))
        
        # The model expects a DataFrame with feature names to avoid warnings
        input_df = pd.DataFrame([[hr, spo2, temp]], columns=['heart_rate', 'spo2', 'temperature_c'])
        
        # Predict Dosha
        prediction = model.predict(input_df)[0]
        
        # Get probabilities
        probabilities = model.predict_proba(input_df)[0]
        prob_dict = {
            class_name: float(prob) 
            for class_name, prob in zip(model.classes_, probabilities)
        }
        
        # Determine confidence score (max probability)
        # We scale it to out of 5 to match the original app's scale loosely, 
        # or just use the probability percentage. Let's just return probabilities.
        confidence = max(probabilities) * 5.0 # Scale to 0-5 to roughly match original rule scores
        
        # Build score dictionary similar to what the app expects
        # The original rule scores were arbitrary, we'll use scaled probabilities
        scores = {k: v * 5.0 for k, v in prob_dict.items()}
        
        return jsonify({
            "dosha": prediction,
            "confidence_score": float(confidence),
            "scores": scores
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 400

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "model_loaded": model is not None})

if __name__ == '__main__':
    print("Starting Dosha Prediction API...")
    app.run(host='0.0.0.0', port=5000, debug=True)
