import streamlit as st
import pandas as pd
import json
import time
import random
from datetime import datetime
import joblib
import warnings

warnings.filterwarnings("ignore", category=UserWarning)

@st.cache_resource
def load_model():
    try:
        return joblib.load("dosha_rf_model.pkl")
    except Exception as e:
        st.error(f"Error loading model: {e}")
        return None

rf_model = load_model()

st.set_page_config(
    page_title="Ayurvedic Dosha Predictor",
    page_icon="🌿",
    layout="wide",
    initial_sidebar_state="expanded"
)

# -----------------------------
# Custom Styling
# -----------------------------
st.markdown("""
<style>
.main-title {
    font-size: 2.2rem;
    font-weight: 700;
    color: #1b4332;
    margin-bottom: 0.2rem;
}
.subtitle {
    color: #52796f;
    margin-bottom: 1rem;
    font-size: 1.1rem;
}
.metric-card {
    padding: 1.5rem;
    border-radius: 12px;
    color: white;
    text-align: center;
    font-weight: 600;
    margin-bottom: 1rem;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    transition: transform 0.2s ease-in-out;
}
.metric-card:hover {
    transform: translateY(-5px);
}
.metric-title {
    font-size: 1rem;
    text-transform: uppercase;
    letter-spacing: 1px;
    margin-bottom: 0.5rem;
    opacity: 0.9;
}
.metric-value {
    font-size: 2rem;
    font-weight: 700;
}
.section-box {
    background-color: #f8f9fa;
    padding: 1.5rem;
    border-radius: 12px;
    border: 1px solid #e9ecef;
    margin-bottom: 1rem;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
}
.small-note {
    font-size: 0.9rem;
    color: #6c757d;
    font-style: italic;
}
h2, h3 {
    color: #2d6a4f;
}
.stTabs [data-baseweb="tab-list"] {
    gap: 2rem;
}
.stTabs [data-baseweb="tab"] {
    height: 3rem;
    white-space: pre-wrap;
    background-color: transparent;
    border-radius: 4px 4px 0 0;
    gap: 1rem;
    padding-top: 10px;
    padding-bottom: 10px;
}
.stTabs [aria-selected="true"] {
    background-color: #e9ecef;
    color: #1b4332 !important;
    font-weight: bold;
}
</style>
""", unsafe_allow_html=True)

# -----------------------------
# Knowledge Base
# -----------------------------
herb_knowledge = {
    "vata": {
        "primary_herbs": ["Ashwagandha", "Brahmi", "Shatavari"],
        "diet_support": [
            "Warm cooked meals",
            "Soups and khichdi",
            "Regular meal timing",
            "Avoid excess cold/dry foods"
        ],
        "lifestyle_support": [
            "Good sleep routine",
            "Gentle yoga",
            "Stress reduction",
            "Warm hydration"
        ],
        "prototype_note": "Grounding and nourishing support"
    },
    "pitta": {
        "primary_herbs": ["Guduchi", "Amla", "Shatavari"],
        "diet_support": [
            "Cooling foods",
            "Avoid overly spicy/oily meals",
            "Hydration",
            "Fresh fruits and lighter meals"
        ],
        "lifestyle_support": [
            "Heat management",
            "Moderate exercise",
            "Relaxation",
            "Avoid overexertion"
        ],
        "prototype_note": "Cooling and soothing support"
    },
    "kapha": {
        "primary_herbs": ["Ginger", "Triphala", "Cinnamon"],
        "diet_support": [
            "Light warm meals",
            "Reduce heavy/oily foods",
            "Avoid overeating",
            "Prefer stimulating spices in moderation"
        ],
        "lifestyle_support": [
            "Daily exercise",
            "Active routine",
            "Avoid oversleeping",
            "Warm water intake"
        ],
        "prototype_note": "Stimulating and lightening support"
    }
}

# -----------------------------
# Helper Functions
# -----------------------------
def assign_dosha_refined_from_values(heart_rate, spo2, temperature_c):
    if rf_model is None:
        # Fallback to zeros if model fails to load
        return "vata", 0.0, {"vata": 0.0, "pitta": 0.0, "kapha": 0.0}
        
    input_df = pd.DataFrame([[heart_rate, spo2, temperature_c]], columns=['heart_rate', 'spo2', 'temperature_c'])
    
    # Predict
    dominant = rf_model.predict(input_df)[0]
    
    # Get probabilities and scale to 0-5 for confidence bucket compatibility
    probabilities = rf_model.predict_proba(input_df)[0]
    prob_dict = {
        class_name: float(prob) 
        for class_name, prob in zip(rf_model.classes_, probabilities)
    }
    
    scores = {k: v * 5.0 for k, v in prob_dict.items()}
    
    # Check if we need to fill in missing doshas with 0 (just in case model classes are missing one)
    for dosha in ["vata", "pitta", "kapha"]:
        if dosha not in scores:
            scores[dosha] = 0.0
            
    confidence_score = max(scores.values())
    
    return dominant, confidence_score, scores

def confidence_bucket(score):
    if score >= 4:
        return "high"
    elif score >= 2:
        return "medium"
    return "low"

def herb_strength(confidence_level):
    if confidence_level == "high":
        return "strong"
    elif confidence_level == "medium":
        return "moderate"
    elif confidence_level == "low":
        return "light"
    return "unknown"

def caution_text(dosha, confidence_level):
    base = "Prototype Ayurvedic wellness suggestion only; not a medical prescription."

    if dosha == "vata":
        extra = " Prioritize rest, warmth, and regular meals."
    elif dosha == "pitta":
        extra = " Prioritize cooling foods, hydration, and avoid excess heat."
    elif dosha == "kapha":
        extra = " Prioritize light diet, movement, and avoid heavy meals."
    else:
        extra = ""

    if confidence_level == "low":
        extra += " Prediction confidence is low, so treat this as a mild suggestion."
    elif confidence_level == "medium":
        extra += " Prediction confidence is moderate."
    elif confidence_level == "high":
        extra += " Prediction confidence is high within this prototype rule base."

    return base + extra

def recommend_for_patient(heart_rate, spo2, temperature_c):
    dosha, score, all_scores = assign_dosha_refined_from_values(heart_rate, spo2, temperature_c)
    kb = herb_knowledge[dosha]
    conf = confidence_bucket(score)

    result = {
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "input_vitals": {
            "heart_rate": round(heart_rate, 1),
            "spo2": round(spo2, 1),
            "temperature_c": round(temperature_c, 2)
        },
        "prediction": {
            "dosha_predicted": dosha,
            "dosha_label": f"{dosha} ({score:.1f})",
            "confidence_level": conf,
            "recommendation_strength": herb_strength(conf),
            "rule_scores": all_scores
        },
        "recommendation": {
            "primary_herbs": kb["primary_herbs"],
            "diet_support": kb["diet_support"],
            "lifestyle_support": kb["lifestyle_support"],
            "prototype_note": kb["prototype_note"],
            "caution_note": caution_text(dosha, conf)
        }
    }
    return result

def dosha_color(dosha):
    colors = {
        "vata": "#7b2cbf",  # Purple
        "pitta": "#e76f51", # Burnt Orange/Red
        "kapha": "#2a9d8f"  # Teal/Green
    }
    return colors.get(dosha, "#264653")

def pretty_rule_df(rule_scores):
    return pd.DataFrame({
        "Dosha": list(rule_scores.keys()),
        "Score": list(rule_scores.values())
    }).sort_values("Score", ascending=False).reset_index(drop=True)

# -----------------------------
# Simulation Helpers
# -----------------------------
def generate_simulated_vitals(base_hr, base_spo2, base_temp):
    """Generates a random walk for vitals to simulate real-time patient data."""
    hr_change = random.uniform(-2, 2)
    spo2_change = random.uniform(-0.5, 0.5)
    temp_change = random.uniform(-0.1, 0.1)

    new_hr = max(40, min(180, base_hr + hr_change))
    new_spo2 = max(80, min(100, base_spo2 + spo2_change))
    new_temp = max(34.0, min(41.0, base_temp + temp_change))
    
    return new_hr, new_spo2, new_temp

# -----------------------------
# Session State Initialization
# -----------------------------
if "patient_history" not in st.session_state:
    st.session_state.patient_history = []
if "is_simulating" not in st.session_state:
    st.session_state.is_simulating = False
if "sim_hr" not in st.session_state:
    st.session_state.sim_hr = 75.0
if "sim_spo2" not in st.session_state:
    st.session_state.sim_spo2 = 98.0
if "sim_temp" not in st.session_state:
    st.session_state.sim_temp = 36.6
if "last_sim_time" not in st.session_state:
    st.session_state.last_sim_time = 0

# -----------------------------
# Header
# -----------------------------
st.markdown('<div class="main-title">🌿 Ayurvedic Dosha Prediction & Monitoring</div>', unsafe_allow_html=True)
st.markdown('<div class="subtitle">AI-assisted real-time dosha classification and wellness recommendations.</div>', unsafe_allow_html=True)
st.markdown("---")

# -----------------------------
# Main Layout: Tabs
# -----------------------------
tab_dashboard, tab_simulation, tab_manual, tab_history, tab_about = st.tabs([
    "📊 Dashboard", 
    "⏱️ Real-Time Simulation", 
    "✍️ Manual Prediction", 
    "📋 Patient History", 
    "ℹ️ About / Future IoT"
])

# Utility to render the result cards
def render_prediction_result(result):
    if not result:
        return
    dosha = result["prediction"]["dosha_predicted"]
    color = dosha_color(dosha)

    col1, col2, col3 = st.columns(3)
    with col1:
        st.markdown(f"""
            <div class="metric-card" style="background-color:{color};">
                <div class="metric-title">Predicted Dosha</div>
                <div class="metric-value">{dosha.upper()}</div>
            </div>
        """, unsafe_allow_html=True)
    with col2:
        st.markdown(f"""
            <div class="metric-card" style="background-color:#3a86ff;">
                <div class="metric-title">Dosha Label & Score</div>
                <div class="metric-value">{result['prediction']['dosha_label']}</div>
            </div>
        """, unsafe_allow_html=True)
    with col3:
        st.markdown(f"""
            <div class="metric-card" style="background-color:#ff006e;">
                <div class="metric-title">Confidence</div>
                <div class="metric-value">{result['prediction']['confidence_level'].upper()}</div>
            </div>
        """, unsafe_allow_html=True)

    st.markdown(f"""
        <div style="padding:16px;border-radius:12px;background-color:{color};color:white;margin-bottom:16px;box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
            <h3 style="margin:0;color:white;">Recommendation Strength: {result['prediction']['recommendation_strength'].upper()}</h3>
            <p style="margin:8px 0 0 0;">{result['recommendation']['prototype_note']}</p>
        </div>
    """, unsafe_allow_html=True)

    left, right = st.columns([1, 1])
    with left:
        st.markdown("### 🫀 Vitals Used")
        vitals_df = pd.DataFrame([result["input_vitals"]])
        st.dataframe(vitals_df, use_container_width=True, hide_index=True)

    with right:
        st.markdown("### 🌿 Primary Herbs")
        herb_cols = st.columns(3)
        herbs = result["recommendation"]["primary_herbs"]
        for i, herb in enumerate(herbs):
            if i < 3:
                herb_cols[i].success(herb)

    col_diet, col_life = st.columns(2)
    with col_diet:
        st.markdown("### 🍲 Diet Support")
        with st.container():
            st.markdown('<div class="section-box">', unsafe_allow_html=True)
            for item in result["recommendation"]["diet_support"]:
                st.write(f"- {item}")
            st.markdown('</div>', unsafe_allow_html=True)

    with col_life:
        st.markdown("### 🧘 Lifestyle Support")
        with st.container():
            st.markdown('<div class="section-box">', unsafe_allow_html=True)
            for item in result["recommendation"]["lifestyle_support"]:
                st.write(f"- {item}")
            st.markdown('</div>', unsafe_allow_html=True)

    st.markdown("### ⚠️ Caution")
    st.warning(result["recommendation"]["caution_note"])


# ==========================================
# TAB 1: Dashboard
# ==========================================
with tab_dashboard:
    st.header("Latest Patient Status")
    if not st.session_state.patient_history:
        st.info("No data available yet. Start the simulation or run a manual prediction.")
    else:
        latest_record = st.session_state.patient_history[-1]
        st.markdown(f"**Last updated:** {latest_record['timestamp']}")
        
        # Render prediction result for latest record
        render_prediction_result(latest_record)
        
        st.markdown("---")
        st.header("Vitals Trend (Latest 50 readings)")
        # Plotly/Altair are slightly heavy, fallback to st.line_chart for native lightweight approach
        history_df = pd.DataFrame([
            {
                "Time": r["timestamp"],
                "Heart Rate": r["input_vitals"]["heart_rate"],
                "SpO2": r["input_vitals"]["spo2"],
                "Temp (C)": r["input_vitals"]["temperature_c"],
                "Dosha": r["prediction"]["dosha_predicted"]
            } for r in st.session_state.patient_history[-50:]
        ])
        
        col_c1, col_c2, col_c3 = st.columns(3)
        with col_c1:
            st.subheader("Heart Rate")
            st.line_chart(history_df.set_index("Time")["Heart Rate"], color="#ff4b4b")
        with col_c2:
            st.subheader("SpO₂ (%)")
            st.line_chart(history_df.set_index("Time")["SpO2"], color="#0068c9")
        with col_c3:
            st.subheader("Temperature (°C)")
            st.line_chart(history_df.set_index("Time")["Temp (C)"], color="#ffb300")


# ==========================================
# TAB 2: Real-Time Simulation
# ==========================================
with tab_simulation:
    st.header("Patient Monitoring Simulator")
    st.markdown("""
    This console simulates continuous minute-by-minute patient vitals. 
    In the final product, this data stream will be replaced by live IoT sensor APIs.
    """)
    
    col_sim1, col_sim2, col_sim3 = st.columns(3)
    
    with col_sim1:
        if st.button("▶️ Start Simulation", use_container_width=True, type="primary"):
            st.session_state.is_simulating = True
            st.toast("Simulation Started!")
    with col_sim2:
        if st.button("⏸️ Pause Simulation", use_container_width=True):
            st.session_state.is_simulating = False
            st.toast("Simulation Paused.")
    with col_sim3:
        if st.button("🔄 Reset History", use_container_width=True):
            st.session_state.is_simulating = False
            st.session_state.patient_history = []
            st.toast("Internal history cleared.")
            st.rerun()
            
    st.markdown("---")
    sim_status = "🟢 ACTIVE" if st.session_state.is_simulating else "🔴 INACTIVE"
    st.markdown(f"### Simulation Status: {sim_status}")
    
    # Simulation settings
    with st.expander("Adjust Patient Baseline Profiles"):
        st.markdown("Change the baseline to simulate different patient conditions.")
        st.markdown("*(Kapha-like: HR~72, SpO2~99, Temp~36.5 | Pitta-like: HR~98, SpO2~98, Temp~37.1 | Vata-like: HR~96, SpO2~94, Temp~36.0)*")
        base_hr = st.slider("Target Heart Rate", 40, 150, int(st.session_state.sim_hr))
        base_spo2 = st.slider("Target SpO2", 80, 100, int(st.session_state.sim_spo2))
        base_temp = st.slider("Target Temp (C)", 35.0, 40.0, float(st.session_state.sim_temp), 0.1)
        
        if st.button("Apply Baseline"):
            st.session_state.sim_hr = base_hr
            st.session_state.sim_spo2 = base_spo2
            st.session_state.sim_temp = base_temp
            st.toast("Baseline Updated.")

    if st.session_state.is_simulating:
        # Generate new data
        st.session_state.sim_hr, st.session_state.sim_spo2, st.session_state.sim_temp = generate_simulated_vitals(
            st.session_state.sim_hr, 
            st.session_state.sim_spo2, 
            st.session_state.sim_temp
        )
        # Predict
        new_result = recommend_for_patient(
            st.session_state.sim_hr, 
            st.session_state.sim_spo2, 
            st.session_state.sim_temp
        )
        # Append
        st.session_state.patient_history.append(new_result)
        
        st.info("Generating new vitals profile... Please switch to the **Dashboard** Tab to see active monitoring data.")
        
        # Loop delay
        time.sleep(2)  # Simulating 1 minute every 2 seconds for demo purposes
        st.rerun()


# ==========================================
# TAB 3: Manual Prediction
# ==========================================
with tab_manual:
    st.header("Manual Data Entry")
    st.markdown("Use this tab to manually test specific vital signs outside of the continuous simulation loop.")
    
    with st.form("manual_input_form"):
        col_m1, col_m2, col_m3 = st.columns(3)
        with col_m1:
            m_hr = st.number_input("Heart Rate (bpm)", 30, 200, 72, 1)
        with col_m2:
            m_spo2 = st.number_input("SpO₂ (%)", 70, 100, 98, 1)
        with col_m3:
            m_temp = st.number_input("Temperature (°C)", 30.0, 42.0, 36.5, 0.1, format="%.1f")
            
        predict_manual = st.form_submit_button("Predict Dosha", use_container_width=True, type="primary")
        
    if predict_manual:
        manual_result = recommend_for_patient(m_hr, m_spo2, m_temp)
        # Save to history so it shows up in history tab as well
        st.session_state.patient_history.append(manual_result)
        st.success("Manual prediction complete!")
        render_prediction_result(manual_result)


# ==========================================
# TAB 4: History & Export
# ==========================================
with tab_history:
    st.header("Patient Monitoring History")
    if not st.session_state.patient_history:
        st.info("No recorded history.")
    else:
        # Flatten history for the dataframe
        flat_history = []
        for r in st.session_state.patient_history:
            flat_history.append({
                "Timestamp": r["timestamp"],
                "Heart Rate": r["input_vitals"]["heart_rate"],
                "SpO2": r["input_vitals"]["spo2"],
                "Temperature (°C)": r["input_vitals"]["temperature_c"],
                "Dosha": r["prediction"]["dosha_predicted"].upper(),
                "Confidence": r["prediction"]["confidence_level"].upper()
            })
        
        hist_df = pd.DataFrame(flat_history)
        st.dataframe(hist_df, use_container_width=True, hide_index=True)
        
        # CSV Export
        csv = hist_df.to_csv(index=False).encode('utf-8')
        st.download_button(
            label="📥 Download CSV History",
            data=csv,
            file_name=f"patient_history_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
            mime="text/csv",
        )
        
        st.markdown("---")
        st.subheader("Latest Reading JSON Export")
        latest_json = json.dumps(st.session_state.patient_history[-1], indent=2)
        st.download_button(
            label="JSON Download",
            data=latest_json.encode('utf-8'),
            file_name="latest_prediction.json",
            mime="application/json"
        )
        with st.expander("View Latest Raw JSON"):
            st.code(latest_json, language="json")


# ==========================================
# TAB 5: About / Future IoT
# ==========================================
with tab_about:
    st.header("System Architecture & Future Scalability")
    
    st.markdown("""
    ### Current Prototype (Simulation Mode)
    This application currently operates as a standalone prototype. Since physical IoT hardware is not yet integrated, 
    the system utilizes a **Real-Time Simulation Engine** to mimic continuous patient monitoring. 
    
    The simulator generates dynamic vital signs (Heart Rate, SpO2, Temperature) by applying randomized perturbations 
    to patient baselines, ensuring realistic fluctuations over time. These mock vitals are then fed into the 
    **Ayurvedic Prediction Engine** every second (simulating a minute-by-minute stream).
    
    ### Future Implementation: True IoT Integration
    The prediction engine and display layer are completely agnostic to the data source. To upgrade this prototype 
    to live patient monitoring:
    
    1. **Sensor Integration**: Deploy wearable or bedside IoT sensors (e.g., MAX30102 for HR/SpO2, DS18B20 for Temp) interfaced with an ESP32 or Raspberry Pi.
    2. **Data Ingestion**: Instead of the local simulator generating tuples, the application will ingest HTTP POST/MQTT requests containing JSON payloads from the IoT hardware.
    3. **Pipeline Upgrade**: The `generate_simulated_vitals` loop will be replaced by an API endpoint listener (e.g., via FastAPI or Streamlit's query params handling) that appends live data directly to the stream.
    
    This modular architecture guarantees that **zero changes** will be needed for the core Dosha recommendation logic, the visualization dashboard, or the UI layout when transitioning from simulated to physical hardware data.
    """)
    
    st.info("Medical Disclaimer: This application provides generalized Ayurvedic wellness suggestions. It is not an FDA-approved diagnostic tool. Consult a physician before starting any herbal regimen.")
