import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/gemini_service.dart';
import 'package:app/getbible_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'GetBibleAPI does not crash on invalid version fetch (simulating error)',
    () async {
      // If it threw an error and wasn't caught, this test would fail
      // By passing an invalid URL/triggering an error, we ensure it's caught and handled gracefully
      // without printing sensitive info to production.
      final result = await GetBibleAPI.getVersions(
        lang: "invalid_format_that_will_throw",
      );
      expect(result, []); // Returns empty list on error
    },
  );

  test(
    'GetBibleAPI does not crash on invalid verse range (start > end)',
    () async {
      final result = await GetBibleAPI.getPassage(
        "web",
        "Genesis 1:5-3",
        lang: "en",
      );
      expect(result, isNull);
    },
  );

  test(
    'GetBibleAPI does not embed a hardcoded default YouVersion API key',
    () {
      expect(GetBibleAPI.defaultYouVersionApiKey, isEmpty);
    },
  );

  test(
    'GeminiService persists and clears API key using FlutterSecureStorage',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final service = GeminiService();
      const testKey = 'AIzaSyTestSecureStorageKey12345678901234';

      await service.saveApiKey(testKey);
      expect(await service.loadApiKey(), testKey);

      await service.saveApiKey('');
      expect(await service.loadApiKey(), isNull);
    },
  );

  test(
    'GetBibleAPI persists and clears YouVersion key using FlutterSecureStorage',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const testYvKey = 'yv-test-secure-key-1234567890';

      await GetBibleAPI.saveYouVersionApiKey(testYvKey);
      expect(await GetBibleAPI.loadYouVersionApiKey(), testYvKey);

      await GetBibleAPI.saveYouVersionApiKey('');
      expect(await GetBibleAPI.loadYouVersionApiKey(), isNull);
    },
  );
}
