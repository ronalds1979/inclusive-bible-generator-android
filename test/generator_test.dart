import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/generator.dart';

void main() {
  group('Generator tests', () {
    test('loadLocales happy path', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final generator = Generator();

      await generator.loadLocales();

      // We expect locales to be loaded for pt-BR, en, and es.
      expect(generator.locales.containsKey('pt-BR'), isTrue);
      expect(generator.locales.containsKey('en'), isTrue);
      expect(generator.locales.containsKey('es'), isTrue);
      expect(generator.locales['en']!.containsKey('title'), isTrue);
    });

    test('loadLocales error path handles missing assets gracefully', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final generator = Generator();
      // Ensure the test bundle doesn't cache from previous test, though
      // Generator is new, rootBundle is global.
      // Wait, rootBundle caches strings. In the first test it was cached.
      // We must use `evict` or clear the cache.
      rootBundle.evict('locales/pt-BR.json');
      rootBundle.evict('locales/en.json');
      rootBundle.evict('locales/es.json');

      // Intercept the default binary messenger to return null when loading assets,
      // simulating missing files or load errors.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
        'flutter/assets',
        (ByteData? message) async {
          return null; // returning null throws "Unable to load asset"
        },
      );

      // Call the method that should catch the exception
      await generator.loadLocales();

      // Verify that the exception was caught and the map is still empty
      expect(generator.locales, isEmpty);

      // Clear the mock handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
        'flutter/assets',
        null,
      );
    });
  });
}
