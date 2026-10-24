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
          'welcome': 'Bem-vindo {name}',
        },
        'en': {
          'hello': 'Hello',
          'welcome': 'Welcome {name}',
        },
        'es': {
          'hello': 'Hola',
        }
      };
    });

    test('should return string for known language without modification', () {
      expect(generator.getLocaleString('en', 'hello'), 'Hello');
      expect(generator.getLocaleString('pt-BR', 'hello'), 'Olá');
      expect(generator.getLocaleString('es', 'hello'), 'Hola');
    });

    test('should normalize complex language strings', () {
      expect(generator.getLocaleString('English (US/UK)', 'hello'), 'Hello');
      expect(generator.getLocaleString('Español (España)', 'hello'), 'Hola');
      expect(generator.getLocaleString('Português', 'hello'), 'Olá');
      expect(generator.getLocaleString('Português (Brasil)', 'hello'), 'Olá');
    });

    test('should fallback to pt-BR for unknown languages', () {
      expect(generator.getLocaleString('fr', 'hello'), 'Olá');
      expect(generator.getLocaleString('unknown', 'hello'), 'Olá');
    });

    test('should return empty string when key is missing', () {
      expect(generator.getLocaleString('en', 'missing_key'), '');
    });

    test('should replace kwargs in template string', () {
      expect(
        generator.getLocaleString('en', 'welcome', kwargs: {'name': 'John'}),
        'Welcome John'
      );
      expect(
        generator.getLocaleString('pt-BR', 'welcome', kwargs: {'name': 'Maria'}),
        'Bem-vindo Maria'
      );
    });

    test('should not alter template if kwargs do not match placeholders', () {
      expect(
        generator.getLocaleString('en', 'welcome', kwargs: {'age': '25'}),
        'Welcome {name}'
      );
    });

    test('should handle multiple kwargs', () {
      generator.locales['en']!['greeting'] = 'Hello {name}, you are {age} years old.';
      expect(
        generator.getLocaleString('en', 'greeting', kwargs: {'name': 'John', 'age': '25'}),
        'Hello John, you are 25 years old.'
      );
    });
  });
}
