void main() {
  List<int> verses = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  int startIdx = 5;
  int endIndex = 4;
  try {
    verses.sublist(startIdx, endIndex);
    print("Success");
  } catch (e) {
    print("Error happened");
  }
}
