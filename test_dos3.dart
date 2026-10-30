import 'package:flutter_test/flutter_test.dart';
import 'package:app/getbible_api.dart';

void main() {
  test('dos3', () async {
    var result = await GetBibleAPI.getPassage("web", "Genesis 1:1-300", lang: "en");
    print(result);
  });
}
