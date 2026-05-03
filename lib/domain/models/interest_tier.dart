import 'dart:convert';

class InterestTier {
  final double threshold;
  final double rate;

  InterestTier({required this.threshold, required this.rate});

  Map<String, dynamic> toMap() => {'threshold': threshold, 'rate': rate};

  factory InterestTier.fromMap(Map<String, dynamic> map) => InterestTier(
    threshold: map['threshold'] is int ? (map['threshold'] as int).toDouble() : map['threshold'],
    rate: map['rate'] is int ? (map['rate'] as int).toDouble() : map['rate'],
  );

  static String toJsonList(List<InterestTier> tiers) => jsonEncode(tiers.map((t) => t.toMap()).toList());
  
  static List<InterestTier> fromJsonList(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    Iterable l = jsonDecode(jsonStr);
    return List<InterestTier>.from(l.map((model) => InterestTier.fromMap(model)));
  }
}