# Ayurvedic Dosha Predictor: Viva & Presentation Guide

This document contains all the necessary details, structural overviews, and flow explanations needed for your project presentation and viva.

---

## 1. Project Overview & Architecture

**Project Goal:** To create a real-time health monitoring system that bridges ancient Ayurvedic principles (Vata, Pitta, Kapha) with modern quantitative physiological data (Heart Rate, SpO2, Temperature).

**Architecture Components:**
1. **Hardware Layer (ESP8266 + Sensors):** Captures physical vitals (HR, SpO2, Temp, IR/Finger detection).
2. **Network/Communication Layer:** Serves data locally over HTTP via an endpoint (`http://<ip>/data`).
3. **Software Interface Layer (Flutter App):** Fetches the data, processes it through a stabilization window, and feeds it to the evaluation logic.
4. **Machine Learning Backend (Python Flask):** A dedicated `api.py` server that hosts the trained Random Forest model (`dosha_rf_model.pkl`) and processes predictions.
5. **Evaluation Engine (Dart Logic):** Communicates with the ML API to map physiological data into Dosha predictions, with a built-in rule-based fallback.
6. **UI Layer:** Displays beautiful, animated dashboard cards, vital wave-forms, and personalized Ayurvedic recommendations.

---

## 2. Project File Structure & Roles

Here is a breakdown of the core files in the project and what they do. This is crucial for viva questions when examiners ask "Where is the logic written?" or "How is the UI built?"

### Backend / Hardware
* **`EmergencyDashboard.ino`**: 
  * *Purpose*: The C++ code running on the ESP8266/ESP32 microcontroller. 
  * *Function*: It interfaces with the physical sensors (like the MAX30102 for HR/SpO2 and DS18B20 for Temperature), reads the raw electrical signals, converts them to numerical vitals, and hosts a lightweight web server to broadcast this data in JSON format.

* **`api.py` (Python Flask API)**:
  * *Purpose*: The Machine Learning Inference Server.
  * *Function*: Loads the trained Random Forest model (`dosha_rf_model.pkl`) and serves predictions via an HTTP endpoint (`/predict`). It receives vitals from the Flutter app, processes them through the ML model, and returns the predicted Dosha and confidence scores.

### Frontend / Mobile App (`dosha_flutter/`)
* **`lib/main.dart`**:
  * *Purpose*: The entry point of the Flutter application.
  * *Function*: It initializes the app, sets up the application theme (dark theme, colors), and injects the `Esp8266Service` state management so it's accessible globally across the app.

* **`lib/screens/dashboard.dart`**:
  * *Purpose*: The primary user interface of the app.
  * *Function*: Contains the layout for the live vitals display, the animated PPG waveform, and the predicted Dosha progress bars. It listens to the `Esp8266Service` and rebuilds the UI whenever new data arrives.

* **`lib/screens/settings.dart`**:
  * *Purpose*: Configuration UI.
  * *Function*: Allows the user to input the IP address of the ESP8266 module on the local network and toggle the "Simulation Mode" for demonstrating the app without physical hardware attached.

* **`lib/services/esp8266_service.dart`**:
  * *Purpose*: The network & state manager.
  * *Function*: 
    - **Data Fetching:** Polls the hardware every 2 seconds via HTTP GET requests.
    - **Finger Detection:** Checks the IR sensor value to verify a finger is actually present on the sensor (`> 10000` threshold).
    - **Stabilization Logic:** Buffers data over a 60-second window (30 readings) to average out noise and provide stable, reliable vitals.
    - **Simulation:** Provides a random-walk generator to mock data when hardware is disconnected.

* **`lib/logic/dosha_calculator.dart`**:
  * *Purpose*: The core "AI Engine" bridge of the application.
  * *Function*: Takes stable HR, SpO2, and Temperature values and sends them to the Python API. If the API is unreachable, it seamlessly falls back to local rule-based physiological thresholds to ensure the app never crashes.

* **`lib/logic/knowledge_base.dart`**:
  * *Purpose*: The recommendation repository.
  * *Function*: Acts as a static database mapping the predicted Doshas (Vata, Pitta, Kapha) to specific dietary, lifestyle, and herbal remedies (e.g., suggesting Guduchi for Pitta).

---

## 3. Data Flow: How Data is Fetched & Processed

If the examiner asks: *"Explain the flow of data from the sensor to the screen."*

**Step 1: Physical Acquisition (Hardware)**
The user places their finger on the sensor. The ESP8266 reads the infrared (IR), red light, and temperature values. It processes these into Heart Rate (BPM), SpO2 (%), and Temperature (°C), and exposes them as a JSON object on `http://<device-ip>/data`.

**Step 2: Polling & Finger Verification (Software - `esp8266_service.dart`)**
The Flutter app starts polling the IP address every 2 seconds. The first thing the app checks in the JSON payload is the `ir` (Infrared) value. 
* If `ir < 10000`, the app knows no finger is present, and auto-clears the screen to prevent stale data.
* If `ir > 10000`, the app confirms finger presence and begins the measurement phase.

**Step 3: The 60-Second Stabilization Buffer**
To ensure high accuracy, the app does not instantly evaluate the first reading. It collects readings every 2 seconds for 1 minute (total 30 readings). Once 30 readings are collected, it calculates the **Average HR, SpO2, and Temp**.

**Step 4: Output**
The averaged, stable vitals are finalized (`_stableVitals`), and the service notifies the UI to update the screen.

---

## 4. Model Evaluation: How the Dosha is Predicted

If the examiner asks: *"How does your algorithm evaluate the vitals to predict the Dosha?"*

The system evaluates the averaged vitals using a **Random Forest Machine Learning Model** trained on historical health data, with a secondary rule-based fallback.

1. **Machine Learning Inference:**
   The stable vitals are sent via HTTP to the Python Flask API. The trained Random Forest classifier (`dosha_rf_model.pkl`) analyzes the non-linear relationships between Heart Rate, SpO2, and Temperature to output a Dosha class prediction and probability scores.

2. **Rule-Based Fallback (If API is offline):**
   * **VATA:** Elevated if HR > 90, Temp < 36.2°C, and SpO2 < 96%.
   * **PITTA:** Elevated if HR > 90 and Temp > 36.8°C.
   * **KAPHA:** Elevated if HR < 75 and Temp is moderate.

3. **Dominant Dosha Extraction:**
   The model returns the Dosha with the highest probability or score, classifying it as the **Dominant Dosha** (e.g., "PITTA").

4. **Percentage Distribution:**
   Simultaneously, a percentage function mathematically scales the deviations from normal baselines to create a 100% distribution pie (e.g., 50% Pitta, 30% Vata, 20% Kapha) for the UI bars.

5. **Confidence Scoring:**
   Based on the probability array returned by the Random Forest model, the app assigns a "High", "Medium", or "Low" confidence tier.

6. **Recommendation Mapping:**
   The dominant Dosha is passed to the `knowledge_base.dart` file, which returns specific lifestyle advice and Ayurvedic herbs tailored to balance that specific physiological state.

---

## 5. Key Highlights to Emphasize in the Presentation
* **Modularity:** Emphasize that the UI, Network, and Logic layers are completely decoupled.
* **Accuracy via Averaging:** Highlight the 60-second stabilization window. This shows you thought about real-world sensor noise and didn't just plug raw, jittery data into the algorithm.
* **Failsafes:** Mention the IR threshold check. The system is smart enough to know when the user removes their finger and automatically clears the dashboard.
* **Simulation Mode:** If hardware fails on presentation day, explain that you built a full simulation mode to ensure the app logic can still be demonstrated flawlessly.
