import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dos5', () {
    List verses = [1, 2, 3, 4, 5];
    int startIdx = 1;
    int endIndex = 0;
    try {
      verses.sublist(startIdx, endIndex);
    } catch (e) {
      print(e);
    }
  });
}
