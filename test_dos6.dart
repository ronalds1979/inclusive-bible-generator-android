import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dos6', () {
    List verses = [1, 2, 3, 4, 5];
    int startIdx = 3;
    int endIdx = 2; // e.g. "Genesis 1:4-3"

    try {
      if (startIdx >= 0 && startIdx < verses.length) {
        int endIndex = endIdx > verses.length ? verses.length : endIdx;
        List selectedVerses = verses.sublist(startIdx, endIndex);
        print("Selected: $selectedVerses");
      }
    } catch (e) {
      print("Crash! \$e");
    }
  });
}
