# Ayurvedic Dosha Prediction & Monitoring App

This repository contains a full-stack **Streamlit** prototype for an **Ayurvedic Dosha Prediction, Notification, and Wellness System**. It utilizes vital signs (Heart Rate, SpO2, Temperature) to predict an individual's predominant Dosha (Vata, Pitta, Kapha) and provides context-aware herbal, dietary, and lifestyle recommendations.

### 🌟 Project Objectives
1. **Academic Demonstration**: Provide a clean, robust, and professional UI to demonstrate algorithmic classification of health vitals.
2. **Real-time IoT Simulation**: Create a visual "Real-time Monitoring" environment that artificially streams patient vitals minute-by-minute, proving that the underlying prediction engine can handle continuous data streams.
3. **Future Scalability**: Ensure zero-rewrite architecture for when actual hardware IoT sensors (wearables/ESP32) are introduced.

---

## 🚀 Features
- **Real-Time Patient Monitoring Simulator:** A dedicated engine generates minute-by-minute patient vitals via a controlled random-walk algorithm, visually updating a dashboard to emulate future live IoT integrations.
- **Robust Dashboard & Visualizations:** Native, lightweight line charting mapping HR, SpO2, and baseline temperature drift over the latest 50 readings.
- **Manual Prediction Engine:** Explicit data-entry tab for running static scenarios, unit-testing the algorithm, or manual inputs.
- **Data Export capabilities:** 1-click downloads for chronological tracking data (CSV) and singular real-time payload extractions (JSON).

---

## 🛠️ Installation & Setup (Local Development)

Ensure you have **Python 3.8+** installed. 

```bash
# 1. Navigate to the project directory
cd ayurveda_dosha_app

# 2. Create a virtual environment (Recommended)
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# 3. Install required dependencies
pip install -r requirements.txt

# 4. Start the Application
streamlit run app.py
```
The application will automatically launch on `http://localhost:8501/`.

---

## 🌐 Deployment Instructions

This app is architected specifically to be stateless and lightweight, making it ideal for immediate cloud deployment without needing Docker or a managed database.

### Option 1: Streamlit Community Cloud (Recommended for Demos)
Streamlit Community Cloud is the fastest way to get this app live on the internet for academic or stakeholder review.

1. Create a GitHub repository and push all files in this directory (`app.py`, `requirements.txt`, etc.).
2. Create an account at [share.streamlit.io](https://share.streamlit.io/).
3. Click **"New App"**.
4. Select your GitHub repository, the main branch, and type `app.py` in the "Main file path" text box.
5. Click **"Deploy"**. The app will be live on a public URL within 60 seconds.

### Option 2: Google Cloud Platform (Cloud Run)
If you require enterprise scaling or plan to hook up physical IoT endpoints through an MQTT broker in the future, GCP Cloud Run is ideal.

**Step 1: Create a `Dockerfile`** (Save this in the project root if deploying to GCP)
```dockerfile
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8080
CMD ["streamlit", "run", "app.py", "--server.port=8080", "--server.address=0.0.0.0"]
```

**Step 2: Deploy via Google Cloud CLI**
```bash
# Initialize gcloud and project
gcloud init
gcloud config set project [YOUR_PROJECT_ID]

# Deploy directly from source to Cloud Run
gcloud run deploy ayurveda-app --source . \
  --platform managed --region us-central1 \
  --allow-unauthenticated
```
GCP will build the container automatically and return a secure `https://` endpoint.

---

## 🔌 Future Concept: Physical IoT Integration

Currently, to demonstrate real-time tracking, the application utilizes an internal simulation loop (`generate_simulated_vitals` in `app.py`).

To scale to physical medical hardware:
1. **Sensors**: Deploy MAX30102 (pulse oximeter) or MLX90614 (infrared thermometer) attached to an ESP32 edge device.
2. **Data Pipeline**: Transmit this packet via MQTT or HTTP POST. 
3. **Pipeline Upgrade**: The simulation loop inside the *Real-Time Simulation* tab will be swapped with a loop fetching from an MQTT topic or a separate FastAPI endpoint. *The prediction logic and UI will remain 100% untouched.*

---
*Medical Disclaimer: This application provides generalized Ayurvedic wellness suggestions. It is not an FDA-approved diagnostic tool.*
