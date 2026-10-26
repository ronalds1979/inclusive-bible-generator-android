import 'package:flutter_test/flutter_test.dart';
import 'package:app/generator.dart';

void main() {
  group('Generator.getLocaleString', () {
    late Generator generator;

    setUp(() {
      generator = Generator();
      generator.locales = {
        'en': {
          'hello': 'Hello',
          'greeting': 'Hello {name}',
        },
        'pt-BR': {
          'hello': 'Olá',
          'greeting': 'Olá {name}',
        },
        'es': {
          'hello': 'Hola',
        }
      };
    });

    test('returns correctly for existing key and language', () {
      expect(generator.getLocaleString('en', 'hello'), 'Hello');
      expect(generator.getLocaleString('pt-BR', 'hello'), 'Olá');
    });

    test('normalizes language names correctly', () {
      expect(generator.getLocaleString('English (US/UK)', 'hello'), 'Hello');
      expect(generator.getLocaleString('Español (España)', 'hello'), 'Hola');
      expect(generator.getLocaleString('Português (Brasil)', 'hello'), 'Olá');
    });

    test('falls back to pt-BR for unknown language', () {
      expect(generator.getLocaleString('fr', 'hello'), 'Olá');
      expect(generator.getLocaleString('unknown', 'hello'), 'Olá');
    });

    test('returns empty string for missing key', () {
      expect(generator.getLocaleString('en', 'missing_key'), '');
      expect(generator.getLocaleString('pt-BR', 'missing_key'), '');
    });

    test('replaces kwargs in template', () {
      expect(
        generator.getLocaleString('en', 'greeting', kwargs: {'name': 'World'}),
        'Hello World',
      );
      expect(
        generator.getLocaleString('pt-BR', 'greeting', kwargs: {'name': 'Mundo'}),
        'Olá Mundo',
      );
    });

    test('ignores kwargs if template has no placeholders', () {
       expect(
        generator.getLocaleString('en', 'hello', kwargs: {'name': 'World'}),
        'Hello',
      );
    });
  });
}
