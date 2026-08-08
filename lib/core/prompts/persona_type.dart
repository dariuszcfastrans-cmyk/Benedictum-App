/// Typ persony Rady Doradczej — kontrakt warstwy UI.
/// D1: system prompty żyją w Edge Function; tutaj wyłącznie metadane UI.
enum PersonaType {
  critic('critic', 'critic'),
  optimist('optimist', 'optimist'),
  coach('coach', 'coach');

  const PersonaType(this.senderId, this.nameKey);

  /// Identyfikator nadawcy w modelu Message.
  final String senderId;

  /// Klucz ARB do nazwy persony.
  final String nameKey;
}
