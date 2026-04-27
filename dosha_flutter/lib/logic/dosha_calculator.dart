import 'dart:convert';
import 'package:http/http.dart' as http;

class DoshaPrediction {
  final String dosha;
  final String label;
  final String confidence;
  final String recommendationStrength;
  final Map<String, double> scores;

  DoshaPrediction({
    required this.dosha,
    required this.label,
    required this.confidence,
    required this.recommendationStrength,
    required this.scores,
  });
}

class DoshaCalculator {
  static Future<DoshaPrediction> predict(double hr, double spo2, double tempC) async {
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'heart_rate': hr,
          'spo2': spo2,
          'temperature_c': tempC,
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String dominant = data['dosha'];
        final double score = data['confidence_score'] ?? 0.0;
        final Map<String, dynamic> rawScores = data['scores'] ?? {};
        
        Map<String, double> scores = {
          "vata": (rawScores["vata"] ?? 0.0).toDouble(),
          "pitta": (rawScores["pitta"] ?? 0.0).toDouble(),
          "kapha": (rawScores["kapha"] ?? 0.0).toDouble(),
        };

        String confidence = _confidenceBucket(score);
        String strength = _herbStrength(confidence);

        return DoshaPrediction(
          dosha: dominant,
          label: "$dominant (${score.toStringAsFixed(1)})",
          confidence: confidence,
          recommendationStrength: strength,
          scores: scores,
        );
      }
    } catch (e) {
      print("API Error: $e");
    }

    // Fallback to rule-based logic if API fails
    return _fallbackPredict(hr, spo2, tempC);
  }

  static DoshaPrediction _fallbackPredict(double hr, double spo2, double tempC) {
    Map<String, double> scores = {"vata": 0.0, "pitta": 0.0, "kapha": 0.0};

    // Vata
    if (hr > 90) scores["vata"] = scores["vata"]! + 2;
    if (tempC < 36.2) scores["vata"] = scores["vata"]! + 2;
    if (spo2 < 96) scores["vata"] = scores["vata"]! + 1;

    // Pitta
    if (hr > 90) scores["pitta"] = scores["pitta"]! + 1;
    if (tempC > 36.8) scores["pitta"] = scores["pitta"]! + 2;
    if (spo2 >= 97) scores["pitta"] = scores["pitta"]! + 1;

    // Kapha
    if (hr < 75) scores["kapha"] = scores["kapha"]! + 2;
    if (36.2 <= tempC && tempC <= 36.8) scores["kapha"] = scores["kapha"]! + 1;
    if (spo2 >= 98) scores["kapha"] = scores["kapha"]! + 2;

    String dominant = "vata";
    double maxScore = -1;
    scores.forEach((key, value) {
      if (value > maxScore) {
        maxScore = value;
        dominant = key;
      }
    });

    String confidence = _confidenceBucket(maxScore);
    String strength = _herbStrength(confidence);

    return DoshaPrediction(
      dosha: dominant,
      label: "$dominant (${maxScore.toStringAsFixed(1)})",
      confidence: confidence,
      recommendationStrength: strength,
      scores: scores,
    );
  }

  static Map<String, double> calculateDoshaPercentages(
      double hr, double spo2, double tempC) {
    double vata  = 33.3;
    double pitta = 33.3;
    double kapha = 33.3;

    // Pitta — heat & speed
    if (hr > 80)    pitta += (hr - 80) * 0.5;
    if (tempC > 36.6) pitta += (tempC - 36.6) * 10;

    // Kapha — slowness & coolness
    if (hr < 70)    kapha += (70 - hr) * 0.5;
    if (tempC < 36.4) kapha += (36.4 - tempC) * 10;

    // Vata — extremes & low SpO2
    if (hr > 100)   vata += (hr - 100) * 0.4;
    if (hr < 60)    vata += (60 - hr) * 0.4;
    if (spo2 < 95)  vata += (95 - spo2) * 2;

    final total = vata + pitta + kapha;
    return {
      'vata':  (vata  / total) * 100,
      'pitta': (pitta / total) * 100,
      'kapha': (kapha / total) * 100,
    };
  }

  static String _confidenceBucket(double score) {
    if (score >= 4) return "high";
    if (score >= 2) return "medium";
    return "low";
  }

  static String _herbStrength(String confidenceLevel) {
    if (confidenceLevel == "high") return "strong";
    if (confidenceLevel == "medium") return "moderate";
    if (confidenceLevel == "low") return "light";
    return "unknown";
  }

  static String getCautionText(String dosha, String confidenceLevel) {
    String base = "Prototype Ayurvedic wellness suggestion only; not a medical prescription.";
    String extra = "";

    if (dosha == "vata") {
      extra = " Prioritize rest, warmth, and regular meals.";
    } else if (dosha == "pitta") {
      extra = " Prioritize cooling foods, hydration, and avoid excess heat.";
    } else if (dosha == "kapha") {
      extra = " Prioritize light diet, movement, and avoid heavy meals.";
    }

    if (confidenceLevel == "low") {
      extra += " Prediction confidence is low, so treat this as a mild suggestion.";
    } else if (confidenceLevel == "medium") {
      extra += " Prediction confidence is moderate.";
    } else if (confidenceLevel == "high") {
      extra += " Prediction confidence is high within this prototype rule base.";
    }

    return base + extra;
  }
}
