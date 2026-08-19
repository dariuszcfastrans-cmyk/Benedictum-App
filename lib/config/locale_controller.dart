import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Języki rozmowy (STT+TTS) wspierane przez Benedictum.
/// Język rozmowy jest niezależny od języka UI i języka systemu urządzenia
/// (dyrektywa R2: SYSTEM LOCALE → sugestia → wybór użytkownika → rozmowa).
/// Priorytet produktu: EN → PL → DE → FR → ES.
enum ConversationLanguage {
  en('en-US', 'English'),
  pl('pl-PL', 'Polski'),
  de('de-DE', 'Deutsch'),
  fr('fr-FR', 'Français'),
  es('es-ES', 'Español');

  const ConversationLanguage(this.ttsLocaleId, this.displayName);

  /// Identyfikator locale dla STT/TTS (np. 'pl-PL').
  final String ttsLocaleId;

  /// Nazwa wyświetlana w UI (własny język, nie lokalizowany).
  final String displayName;

  static ConversationLanguage fromLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'pl':
        return ConversationLanguage.pl;
      case 'de':
        return ConversationLanguage.de;
      case 'fr':
        return ConversationLanguage.fr;
      case 'es':
        return ConversationLanguage.es;
      default:
        return ConversationLanguage.en;
    }
  }
}

/// Kontroler bieżących języków aplikacji.
///
/// - [uiLocale] — język interfejsu (MaterialApp locale).
/// - [conversationLanguage] — niezależny język rozmowy (STT+TTS).
///
/// Oba zapisywane w SharedPreferences (persystencja między uruchomieniami).
/// Wartości domyślne: UI = PL (dev), rozmowa = EN (produkt).
class LocaleController {
  LocaleController._();

  static final LocaleController instance = LocaleController._();

  static const String _uiKey = 'locale_ui';
  static const String _conversationKey = 'locale_conversation';

  final ValueNotifier<Locale> locale = ValueNotifier(const Locale('pl'));

  /// Język rozmowy (STT+TTS) — niezależna decyzja użytkownika.
  final ValueNotifier<ConversationLanguage> conversationLanguage =
      ValueNotifier(ConversationLanguage.en);

  bool _loaded = false;

  /// Czy wartości zostały wczytane z pamięci (persystencja).
  bool get loaded => _loaded;

  /// Wczytuje zapisane locale (UI + rozmowa). Wywoływane raz przy starcie.
  /// Brak zapisu → wartości domyślne (sugestia; użytkownik może zmienić).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ui = prefs.getString(_uiKey);
    final conversation = prefs.getString(_conversationKey);
    if (ui != null) {
      final parts = ui.split('-');
      if (parts.isNotEmpty) {
        locale.value = Locale(parts[0], parts.length > 1 ? parts[1] : null);
      }
    }
    if (conversation != null) {
      conversationLanguage.value =
          ConversationLanguage.values.firstWhere(
            (l) => l.name == conversation,
            orElse: () => ConversationLanguage.en,
          );
    }
    _loaded = true;
  }

  /// Zmienia język interfejsu i zapisuje go (bez restartu procesu).
  void setUiLocale(Locale newLocale) {
    locale.value = newLocale;
    _save();
  }

  /// Zmienia język rozmowy (STT+TTS) i zapisuje go.
  void setConversationLanguage(ConversationLanguage language) {
    conversationLanguage.value = language;
    _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final ui = locale.value;
    await prefs.setString(
      _uiKey,
      ui.languageCode + (ui.countryCode != null ? '-${ui.countryCode}' : ''),
    );
    await prefs.setString(_conversationKey, conversationLanguage.value.name);
  }
}