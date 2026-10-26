import 'package:flutter_test/flutter_test.dart';
import 'package:app/getbible_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('GetBibleAPI does not crash on invalid version fetch (simulating error)', () async {
    // If it threw an error and wasn't caught, this test would fail
    // By passing an invalid URL/triggering an error, we ensure it's caught and handled gracefully
    // without printing sensitive info to production.
    final result = await GetBibleAPI.getVersions(lang: "invalid_format_that_will_throw");
    expect(result, []); // Returns empty list on error
  });
}
