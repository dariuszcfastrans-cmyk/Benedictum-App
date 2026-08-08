/// Model scenariusza treningowego Benedictum.
class Scenario {
  const Scenario({
    required this.id,
    required this.titleKey,
  });

  final String id;

  /// Klucz ARB do tytułu scenariusza.
  final String titleKey;
}
