import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/generator.dart'; // Adjust if package name is different

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Performance test for generateImageBytes', () async {
    final generator = Generator();

    // Create a dummy image file
    final tempDir = await Directory.systemTemp.createTemp('perf_test');
    final dummyFile = File('${tempDir.path}/dummy.png');
    // 1x1 pixel PNG
    final bytes = [
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
      0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84,
      8, 215, 99, 248, 255, 255, 63, 0, 5, 254, 2, 254, 220, 204, 89, 231, 0, 0,
      0, 0, 73, 69, 78, 68, 174, 66, 96, 130
    ];
    await dummyFile.writeAsBytes(bytes);

    // Warm up
    await generator.generateImageBytes('en', 'John 3:16', 'John 3:16', customImagePath: dummyFile.path);

    // Measure
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 20; i++) {
      await generator.generateImageBytes('en', 'John 3:16', 'John 3:16', customImagePath: dummyFile.path);
    }
    stopwatch.stop();
    print('Time taken for 20 iterations: ${stopwatch.elapsedMilliseconds} ms');

    await tempDir.delete(recursive: true);
  });
}
