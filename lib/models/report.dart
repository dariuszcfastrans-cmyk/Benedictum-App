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
    // R7 (KROK 7, defensywnie): kontrakt wymaga overall_rating 1–5. Backend egzekwuje
    // (parseReport w core), klient broni się przed untrusted input spoza zakresu:
    // int/num w 1–5 → wprost; spoza zakresu lub nie-liczba → neutralne 3 (zamiast „0/5").
    final int safeRating;
    if (rating is int) {
      safeRating = (rating >= 1 && rating <= 5) ? rating : 3;
    } else if (rating is num) {
      final r = rating.toInt();
      safeRating = (r >= 1 && r <= 5) ? r : 3;
    } else {
      safeRating = 3;
    }
    return Report(
      strengths: stringList(json['strengths']),
      gaps: stringList(json['gaps']),
      actionItems: stringList(json['action_items']),
      overallRating: safeRating,
    );
  }
}