/// Model raportu końcowego sesji (kontrakt Dyrektywy 2A §3).
/// Raport jest generowany przez LLM i traktowany jako untrusted input —
/// render UI traktuje pola jako tekst (§22).
class Report {
  const Report({
    required this.strengths,
    required this.gaps,
    required this.actionItems,
    required this.overallRating,
  });

  final List<String> strengths;
  final List<String> gaps;
  final List<String> actionItems;
  final int overallRating;

  factory Report.fromJson(Map<String, dynamic> json) {
    List<String> stringList(dynamic value) {
      if (value is! List) return const [];
      return value.whereType<String>().toList();
    }

    final rating = json['overall_rating'];
    return Report(
      strengths: stringList(json['strengths']),
      gaps: stringList(json['gaps']),
      actionItems: stringList(json['action_items']),
      overallRating: rating is int ? rating : (rating is num ? rating.toInt() : 0),
    );
  }
}