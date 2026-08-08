import 'package:flutter/material.dart';

/// Kontroler bieżącego języka aplikacji.
/// Pozwala zmieniać locale w najwyższym MaterialApp bez restartu procesu.
class LocaleController {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  final ValueNotifier<Locale> locale = ValueNotifier(const Locale('pl'));
}
