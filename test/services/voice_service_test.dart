import 'package:flutter_test/flutter_test.dart';

import 'package:benedictum_mobile/services/voice_service.dart';

// R-TTS: TTS czyta CZYSTY tekst — VoiceService.stripMarkdown usuwa znaczniki
// Markdown zanim tekst trafi do syntezy, aby TTS nie odczytywał **/#/-/1. itd.
void main() {
  group('stripMarkdown (R-TTS)', () {
    test('usuwa pogrubienie i kursywę', () {
      expect(
        VoiceService.stripMarkdown('To jest **ważne** i _podkreślone_.'),
        'To jest ważne i podkreślone.',
      );
    });

    test('usuwa nagłówki i listy na początku linii', () {
      expect(
        VoiceService.stripMarkdown('# Nagłówek\n- punkt\n1. numer\n> cytat'),
        'Nagłówek\npunkt\nnumer\ncytat',
      );
    });

    test('zamienia link na sam tekst', () {
      expect(
        VoiceService.stripMarkdown('Zobacz [dokument](https://example.com)'),
        'Zobacz dokument',
      );
    });

    test('usuwa kod inline', () {
      expect(
        VoiceService.stripMarkdown('Użyj `final x = 1`'),
        'Użyj final x = 1',
      );
    });

    test('czyści przekreślenie', () {
      expect(
        VoiceService.stripMarkdown('To ~~jest~~ już nieaktualne'),
        'To jest już nieaktualne',
      );
    });

    test('zwykły tekst bez markdown pozostaje nietknięty', () {
      expect(
        VoiceService.stripMarkdown('Zwykła wypowiedź bez formatowania.'),
        'Zwykła wypowiedź bez formatowania.',
      );
    });

    test('pusty tekst zwraca pusty tekst', () {
      expect(VoiceService.stripMarkdown(''), '');
    });
  });
}