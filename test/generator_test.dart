import 'package:flutter_test/flutter_test.dart';
import 'package:app/generator.dart';

void main() {
  group('Generator.getLocaleString', () {
    late Generator generator;

    setUp(() {
      generator = Generator();
      // Setup mock locales for testing
      generator.locales = {
        'pt-BR': {
          'hello': 'Olá',
          'welcome': 'Bem-vindo, {name}!',
        },
        'en': {
          'hello': 'Hello',
          'welcome': 'Welcome, {name}!',
        },
        'es': {
          'hello': 'Hola',
        },
      };
    });

    test('normalizes language names correctly', () {
      expect(generator.getLocaleString('English (US/UK)', 'hello'), 'Hello');
      expect(generator.getLocaleString('Español (España)', 'hello'), 'Hola');
      expect(generator.getLocaleString('Português', 'hello'), 'Olá');
      expect(generator.getLocaleString('Português (Brasil)', 'hello'), 'Olá');
    });

    test('falls back to pt-BR for unknown languages', () {
      expect(generator.getLocaleString('unknown', 'hello'), 'Olá');
      expect(generator.getLocaleString('fr', 'hello'), 'Olá');
    });

    test('returns exact string when no kwargs are provided', () {
      expect(generator.getLocaleString('en', 'hello'), 'Hello');
    });

    test('replaces placeholders with kwargs', () {
      expect(
        generator.getLocaleString('en', 'welcome', kwargs: {'name': 'John'}),
        'Welcome, John!',
      );
    });

    test('returns empty string for missing keys', () {
      expect(generator.getLocaleString('en', 'missing_key'), '');
    });

    test('handles multiple placeholders (if we added one)', () {
      generator.locales['en']!['multiple'] = '{greeting}, {name}!';
      expect(
        generator.getLocaleString('en', 'multiple', kwargs: {
          'greeting': 'Hi',
          'name': 'Alice'
        }),
        'Hi, Alice!',
      );
    });
  });
}
