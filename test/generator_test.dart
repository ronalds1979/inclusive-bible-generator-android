import 'package:flutter_test/flutter_test.dart';
import '../lib/generator.dart';

void main() {
  group('Generator tests', () {
    test('generateTexts returns correct strings for existing locale', () async {
      final generator = Generator();
      generator.locales = {
        'en': {
          'default_description': 'A beautiful verse',
          'alt_text_template': '{description} - {verse} ({reference})',
          'caption_template': '{verse}\n\n- {reference}',
        }
      };

      final result = await generator.generateTexts('en', 'Jesus wept.', 'John 11:35');

      expect(result['altText'], 'A beautiful verse - Jesus wept. (John 11:35)');
      expect(result['caption'], 'Jesus wept.\n\n- John 11:35');
    });

    test('generateTexts falls back to pt-BR if locale not found', () async {
      final generator = Generator();
      generator.locales = {
        'pt-BR': {
          'default_description': 'Um verso bonito',
          'alt_text_template': '{description} - {verse} ({reference})',
          'caption_template': '{verse}\n\n- {reference}',
        }
      };

      // Passing 'fr' should fallback to 'pt-BR' since 'fr' is not in the map
      final result = await generator.generateTexts('fr', 'Jesus chorou.', 'João 11:35');

      expect(result['altText'], 'Um verso bonito - Jesus chorou. (João 11:35)');
      expect(result['caption'], 'Jesus chorou.\n\n- João 11:35');
    });

    test('generateTexts handles missing keys gracefully', () async {
      final generator = Generator();
      generator.locales = {
        'en': {
          // Missing 'default_description' and 'caption_template'
          'alt_text_template': '{description} - {verse} ({reference})',
        }
      };

      final result = await generator.generateTexts('en', 'Jesus wept.', 'John 11:35');

      expect(result['altText'], ' - Jesus wept. (John 11:35)');
      expect(result['caption'], '');
    });

    test('generateTexts strips specific country modifiers correctly', () async {
      final generator = Generator();
      generator.locales = {
        'en': {
          'default_description': 'A beautiful verse',
          'alt_text_template': '{description} - {verse} ({reference})',
          'caption_template': '{verse}\n\n- {reference}',
        }
      };

      // "English (US/UK)" should be stripped/replaced to "en"
      final result = await generator.generateTexts('English (US/UK)', 'Jesus wept.', 'John 11:35');

      expect(result['altText'], 'A beautiful verse - Jesus wept. (John 11:35)');
      expect(result['caption'], 'Jesus wept.\n\n- John 11:35');
    });
  });
}
