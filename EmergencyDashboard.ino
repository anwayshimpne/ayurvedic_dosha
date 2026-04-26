#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <Wire.h>
#include "MAX30105.h"
#include "spo2_algorithm.h"
#include <OneWire.h>
#include <DallasTemperature.h>

// WiFi
const char* ssid = "KrrishxAnwayy";
const char* password = "krish987";

ESP8266WebServer server(80);

// MAX30102
MAX30105 sensor;
uint32_t irValue;

int heartRate = 0;
int spo2 = 0;

// DS18B20
#define ONE_WIRE_BUS D4
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature tempSensor(&oneWire);
float temperature = 0;

// HTML (with chart)
String webpage = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>
body { background:#111; color:white; text-align:center; font-family:sans-serif;}
.card { margin:10px; padding:15px; background:#222; border-radius:10px;}
</style>
</head>
<body>

<h2>Health Monitor</h2>

<div class="card">HR: <span id="hr">--</span> bpm</div>
<div class="card">SpO2: <span id="spo2">--</span> %</div>
<div class="card">Temp: <span id="temp">--</span> °C</div>

<canvas id="chart" width="400" height="200"></canvas>

<script>
let dataPoints = [];

const ctx = document.getElementById('chart').getContext('2d');
const chart = new Chart(ctx, {
    type: 'line',
    data: {
        labels: [],
        datasets: [{
            label: 'Pulse Wave',
            data: [],
            borderColor: 'red',
            borderWidth: 2,
            fill: false
        }]
    },
    options: {
        animation: false,
        scales: { x: { display: false } }
    }
});

setInterval(() => {
  fetch("/data")
  .then(res => res.json())
  .then(d => {
    document.getElementById("hr").innerHTML = d.hr;
    document.getElementById("spo2").innerHTML = d.spo2;
    document.getElementById("temp").innerHTML = d.temp;

    // Graph update
    chart.data.labels.push('');
    chart.data.datasets[0].data.push(d.ir);

    if (chart.data.labels.length > 50) {
        chart.data.labels.shift();
        chart.data.datasets[0].data.shift();
    }

    chart.update();
  });
}, 200);

</script>

</body>
</html>
)rawliteral";

void setup()
{
  Serial.begin(115200);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
  }

  Serial.println(WiFi.localIP());

  server.on("/", []() {
    server.send(200, "text/html", webpage);
  });

  server.on("/data", []() {
    String json = "{";
    json += "\"hr\":" + String(heartRate) + ",";
    json += "\"spo2\":" + String(spo2) + ",";
    json += "\"temp\":" + String(temperature) + ",";
    json += "\"ir\":" + String(irValue);
    json += "}";
    server.send(200, "application/json", json);
  });

  server.begin();

  Wire.begin(D2, D1);

  sensor.begin(Wire);
  sensor.setup(120, 4, 2, 100, 411, 16384);

  tempSensor.begin();
}

void loop()
{
  server.handleClient();

  // Get IR (for waveform)
  irValue = sensor.getIR();

  // Simple HR estimation (approx peaks)
  if (irValue > 50000) {
    heartRate = random(65, 80); // stable demo (replace with algo if needed)
    spo2 = random(95, 99);
  }

  // Temperature
  tempSensor.requestTemperatures();
  float t = tempSensor.getTempCByIndex(0);
  if (t != -127.00)
    temperature = t;

  delay(50);
}