import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:app/generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Benchmark loadLocales', () async {
    final generator = Generator();

    // Warmup
    for (int i = 0; i < 5; i++) {
      await generator.loadLocales();
    }

    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < 100; i++) {
      await generator.loadLocales();
    }

    stopwatch.stop();
    debugPrint(
      'loadLocales 100 times took: ${stopwatch.elapsedMilliseconds} ms',
    );
  });
}
