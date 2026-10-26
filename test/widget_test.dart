import 'package:flutter_test/flutter_test.dart';
import 'package:app/getbible_api.dart';

void main() {
  test('API Fetch works successfully', () async {
    final versions = await GetBibleAPI.getVersions(lang: "pt");
    expect(versions.isNotEmpty, isTrue);
  });
}
