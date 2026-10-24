import 'package:flutter_test/flutter_test.dart';
import '../lib/generator.dart';

void main() {
  group('Generator tests', () {
    late Generator generator;

    setUp(() {
      generator = Generator();
      generator.locales = {
        'en': {
          'default_description': 'A beautiful Bible verse image.',
          'alt_text_template': '{description} Verse: {verse} - {reference}',
          'caption_template': 'Read {reference}: {verse}'
        },
        'pt-BR': {
          'default_description': 'Uma linda imagem de versículo bíblico.',
          'alt_text_template': '{description} Versículo: {verse} - {reference}',
          'caption_template': 'Leia {reference}: {verse}'
        }
      };
    });

    test('generateTexts uses correct language templates', () async {
      final result = await generator.generateTexts('en', 'Jesus wept.', 'John 11:35');

      expect(result['altText'], 'A beautiful Bible verse image. Verse: Jesus wept. - John 11:35');
      expect(result['caption'], 'Read John 11:35: Jesus wept.');
    });

    test('generateTexts falls back to pt-BR if language is unknown', () async {
      final result = await generator.generateTexts('unknown-lang', 'Jesus wept.', 'John 11:35');

      expect(result['altText'], 'Uma linda imagem de versículo bíblico. Versículo: Jesus wept. - John 11:35');
      expect(result['caption'], 'Leia John 11:35: Jesus wept.');
    });

    test('generateTexts maps string language replacements correctly', () async {
      final result = await generator.generateTexts('English (US/UK)', 'Jesus wept.', 'John 11:35');

      expect(result['altText'], 'A beautiful Bible verse image. Verse: Jesus wept. - John 11:35');
      expect(result['caption'], 'Read John 11:35: Jesus wept.');
    });

    test('generateTexts handles missing keys gracefully', () async {
      generator.locales['en'] = {};
      final result = await generator.generateTexts('en', 'Jesus wept.', 'John 11:35');

      expect(result['altText'], '');
      expect(result['caption'], '');
    });
  });
}
