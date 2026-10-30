void main() {
  RegExp regExp = RegExp(
    r'^((?:\d\s+)?[a-zA-ZáéíóúãõçñÁÉÍÓÚÃÕÇÑ]+(?:\s+[a-zA-ZáéíóúãõçñÁÉÍÓÚÃÕÇÑ]+)*)\s+(\d+)(?::(\d+)(?:-(\d+))?)?$',
  );

  String malformed = "1 Samuel " + "a " * 50 + " b";

  print("Testing string length: ${malformed.length}");

  var sw = Stopwatch()..start();
  var match = regExp.firstMatch(malformed);
  sw.stop();

  print("Time taken: ${sw.elapsedMilliseconds} ms");
}
