import 'package:flutter/material.dart';

import 'app.dart';
import 'services/revenuecat_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // C1: init SDK offline.
  // - RevenueCat: placeholder (pusty klucz tolerowany przez SDK), C2 = prawdziwy.
  // - OneSignal: NIE inicjalizowany w C1 — wymaga prawdziwego App ID (STOP).
  // - Supabase: NIE inicjalizowany w C1 — brak w kodzie (grep dowodowy).
  await RevenueCatService.instance.init(apiKey: '');

  runApp(BenedictumApp());
}
