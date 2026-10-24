import 'dart:core';

void main() {
  Map<String, int> mapping = {
    for (int i = 0; i < 100; i++) "BookName$i": i
  };
  mapping["Gênesis"] = 1;
  mapping["Êxodo"] = 2;
  mapping["Levítico"] = 3;
  mapping["Números"] = 4;
  mapping["Apocalipse"] = 66;

  String bookName = "apocalipse";

  int iterations = 1000000;

  // Baseline
  Stopwatch sw = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    int? bookNr;
    for (var entry in mapping.entries) {
      if (entry.key.toLowerCase() == bookName.toLowerCase()) {
        bookNr = entry.value;
        break;
      }
    }
  }
  sw.stop();
  print("Baseline: ${sw.elapsedMilliseconds} ms");

  // Optimized
  sw.reset();
  sw.start();
  for (int i = 0; i < iterations; i++) {
    int? bookNr;
    String bookNameLower = bookName.toLowerCase();
    for (var entry in mapping.entries) {
      if (entry.key.toLowerCase() == bookNameLower) {
        bookNr = entry.value;
        break;
      }
    }
  }
  sw.stop();
  print("Optimized: ${sw.elapsedMilliseconds} ms");
}
