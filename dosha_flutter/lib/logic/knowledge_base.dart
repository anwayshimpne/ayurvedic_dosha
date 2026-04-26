class KnowledgeBase {
  static const Map<String, Map<String, dynamic>> herbKnowledge = {
    "vata": {
      "description":
          "Vata governs movement, breath, and the nervous system. It is light, dry, and quick — when balanced it brings creativity and vitality; when excess, it causes anxiety and restlessness.",
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
      "description":
          "Pitta governs digestion, metabolism, and transformation. It is hot, sharp, and intense — when balanced it brings intelligence and courage; when excess, it leads to inflammation and irritability.",
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
      "description":
          "Kapha governs structure, lubrication, and stability. It is heavy, slow, and steady — when balanced it brings strength and calm; when excess, it causes lethargy and congestion.",
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
  };
}
