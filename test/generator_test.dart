import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/generator.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadLocales error path is handled correctly', () async {
    final generator = Generator();

    // Return null to simulate asset not found, which will cause rootBundle to throw an exception
    // This will trigger the catch block in loadLocales
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      return null;
    });

    await generator.loadLocales();
    expect(generator.locales.isEmpty, isTrue);
  });
}
