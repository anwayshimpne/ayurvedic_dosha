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
  // ── Normal vital ranges ────────────────────────────────────────────────────
  // Single source of truth — update here to affect both alerts and future logic.
  static const Map<String, Map<String, double>> normalRanges = {
    'hr':   {'min': 50.0, 'max': 120.0},
    'spo2': {'min': 92.0, 'max': 100.0},
    'temp': {'min': 35.0, 'max': 38.0},
  };

  /// Returns true if [value] falls outside the normal range for [vital].
  static bool isAbnormal(String vital, double value) {
    final range = normalRanges[vital];
    if (range == null) return false;
    return value < range['min']! || value > range['max']!;
  }

  static DoshaPrediction predict(double hr, double spo2, double tempC) {
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
    const _cautions = {
      'vata': {
        'high':   'Your readings strongly suggest elevated Vata. Prioritise warmth, grounding routines, and nourishing meals — and consult an Ayurvedic practitioner for personalised guidance.',
        'medium': 'Your readings moderately suggest elevated Vata. Focus on regular sleep, warm foods, and reducing stress where possible.',
        'low':    'A mild Vata tendency is indicated, though confidence is low. Treat this as a gentle reminder to stay warm and maintain steady daily habits.',
      },
      'pitta': {
        'high':   'Your readings strongly suggest elevated Pitta. Prioritise cooling foods, adequate hydration, and avoiding excess heat or overexertion — consult a practitioner if symptoms persist.',
        'medium': 'Your readings moderately suggest elevated Pitta. Favour lighter, cooling meals and make time for relaxation throughout the day.',
        'low':    'A mild Pitta tendency is indicated, though confidence is low. Staying hydrated and avoiding unnecessarily spicy meals is a reasonable precaution.',
      },
      'kapha': {
        'high':   'Your readings strongly suggest elevated Kapha. Prioritise light warm meals, daily movement, and an energising routine — consult a practitioner for a tailored plan.',
        'medium': 'Your readings moderately suggest elevated Kapha. Incorporate regular activity and prefer lighter, spiced foods to keep energy levels up.',
        'low':    'A mild Kapha tendency is indicated, though confidence is low. Staying active and avoiding heavy or oily foods is a sensible precaution.',
      },
    };

    final text = _cautions[dosha]?[confidenceLevel];
    return text ??
        'Prototype Ayurvedic wellness suggestion only — not a medical prescription. Please consult a qualified practitioner for personalised advice.';
  }

  // ── Vital Insight ──────────────────────────────────────────────────────────
  /// Returns a short, human-readable string explaining which dosha(s) a given
  /// vital reading influences — mirrors the exact scoring rules in [predict].
  static VitalInsight getVitalInsight(String vital, double value) {
    switch (vital) {
      case 'hr':
        if (value > 100) return VitalInsight('Vata ↑↑  Pitta ↑', 'vata');
        if (value > 90)  return VitalInsight('Vata ↑  Pitta ↑', 'vata');
        if (value < 60)  return VitalInsight('Kapha ↑↑', 'kapha');
        if (value < 75)  return VitalInsight('Kapha ↑', 'kapha');
        return VitalInsight('Balanced signal', null);

      case 'spo2':
        if (value >= 98) return VitalInsight('Kapha ↑↑', 'kapha');
        if (value >= 97) return VitalInsight('Pitta ↑', 'pitta');
        if (value < 92)  return VitalInsight('Vata ↑↑', 'vata');
        if (value < 96)  return VitalInsight('Vata ↑', 'vata');
        return VitalInsight('Balanced signal', null);

      case 'temp':
        if (value > 37.5) return VitalInsight('Pitta ↑↑', 'pitta');
        if (value > 36.8) return VitalInsight('Pitta ↑', 'pitta');
        if (value < 35.5) return VitalInsight('Vata ↑↑', 'vata');
        if (value < 36.2) return VitalInsight('Vata ↑', 'vata');
        return VitalInsight('Kapha ↑', 'kapha');

      default:
        return VitalInsight('—', null);
    }
  }
}

/// Carries the insight label and the primary dosha it signals (null = balanced).
class VitalInsight {
  final String label;
  final String? dosha; // 'vata' | 'pitta' | 'kapha' | null
  const VitalInsight(this.label, this.dosha);
}
