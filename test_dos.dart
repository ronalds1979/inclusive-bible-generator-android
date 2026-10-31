import 'package:flutter_test/flutter_test.dart';
import 'package:app/getbible_api.dart';

void main() {
  test('empty test', () async {
    var result = await GetBibleAPI.getPassage(
      "web",
      "Genesis 1:5-3",
      lang: "en",
    );
    print(result);
  });
}
