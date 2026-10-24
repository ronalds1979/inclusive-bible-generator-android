import 'package:flutter_test/flutter_test.dart';
import 'package:app/generator.dart';

void main() {
  group('Generator.getLocaleString', () {
    late Generator generator;

    setUp(() {
      generator = Generator();
      // Setup mock locales for testing without relying on file loading
      generator.locales = {
        'pt-BR': {
          'hello': 'Olá',
          'welcome': 'Bem-vindo, {name}!',
          'test_key': 'Test PT',
        },
        'en': {
          'hello': 'Hello',
          'welcome': 'Welcome, {name}!',
          'test_key': 'Test EN',
        },
        'es': {
          'hello': 'Hola',
          'welcome': '¡Bienvenido, {name}!',
        },
      };
    });

    test('basic string retrieval without kwargs', () {
      expect(generator.getLocaleString('en', 'hello'), 'Hello');
      expect(generator.getLocaleString('pt-BR', 'hello'), 'Olá');
    });

    test('language string normalization', () {
      expect(generator.getLocaleString('English (US/UK)', 'hello'), 'Hello');
      expect(generator.getLocaleString('Português (Brasil)', 'hello'), 'Olá');
      expect(generator.getLocaleString('Português', 'hello'), 'Olá');
      expect(generator.getLocaleString('Español (España)', 'hello'), 'Hola');
    });

    test('fallback to pt-BR when language is not found', () {
      expect(generator.getLocaleString('fr', 'test_key'), 'Test PT');
      expect(generator.getLocaleString('unknown', 'hello'), 'Olá');
    });

    test('fallback to empty string when key is not found', () {
      expect(generator.getLocaleString('en', 'missing_key'), '');
      expect(generator.getLocaleString('pt-BR', 'nonexistent'), '');
    });

    test('kwargs replacement', () {
      expect(
        generator.getLocaleString('en', 'welcome', kwargs: {'name': 'John'}),
        'Welcome, John!',
      );
      expect(
        generator.getLocaleString('pt-BR', 'welcome', kwargs: {'name': 'Maria'}),
        'Bem-vindo, Maria!',
      );
    });

    test('kwargs replacement with multiple replacements (simulated)', () {
      generator.locales['en']!['complex'] = 'Hello {first} {last}';
      expect(
        generator.getLocaleString('en', 'complex', kwargs: {'first': 'John', 'last': 'Doe'}),
        'Hello John Doe',
      );
    });
  });
}
