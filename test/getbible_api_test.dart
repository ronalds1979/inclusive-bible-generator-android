import 'package:flutter_test/flutter_test.dart';
import 'package:app/getbible_api.dart';

void main() {
  group('GetBibleAPI.parseReference', () {
    test('parses simple book and chapter', () {
      final result = GetBibleAPI.parseReference("Genesis 1");
      expect(result, {
        "book_nr": "1",
        "chapter": "1",
        "start_verse": null,
        "end_verse": null,
      });
    });

    test('parses book, chapter, and verse', () {
      final result = GetBibleAPI.parseReference("John 3:16");
      expect(result, {
        "book_nr": "43",
        "chapter": "3",
        "start_verse": "16",
        "end_verse": null,
      });
    });

    test('parses book, chapter, and verse range', () {
      final result = GetBibleAPI.parseReference("John 3:16-18");
      expect(result, {
        "book_nr": "43",
        "chapter": "3",
        "start_verse": "16",
        "end_verse": "18",
      });
    });

    test('parses books with numbers in their names', () {
      final result = GetBibleAPI.parseReference("1 John 1:9");
      expect(result, {
        "book_nr": "62",
        "chapter": "1",
        "start_verse": "9",
        "end_verse": null,
      });
    });

    test('parses multi-word books', () {
      final result = GetBibleAPI.parseReference("Song of Solomon 2:1");
      expect(result, {
        "book_nr": "22",
        "chapter": "2",
        "start_verse": "1",
        "end_verse": null,
      });
    });

    test('parses Portuguese references', () {
      final result = GetBibleAPI.parseReference("Gênesis 1:1", lang: "pt");
      expect(result, {
        "book_nr": "1",
        "chapter": "1",
        "start_verse": "1",
        "end_verse": null,
      });
    });

    test('parses Portuguese reference with number in name', () {
      final result = GetBibleAPI.parseReference("1 Coríntios 13:4-7", lang: "pt");
      expect(result, {
        "book_nr": "46",
        "chapter": "13",
        "start_verse": "4",
        "end_verse": "7",
      });
    });

    test('parses Spanish references', () {
      final result = GetBibleAPI.parseReference("Génesis 1:1", lang: "es");
      expect(result, {
        "book_nr": "1",
        "chapter": "1",
        "start_verse": "1",
        "end_verse": null,
      });
    });

    test('returns null values for invalid formats (empty string)', () {
      final result = GetBibleAPI.parseReference("");
      expect(result, {
        "book_nr": null,
        "chapter": null,
        "start_verse": null,
        "end_verse": null,
      });
    });

    test('returns null values for missing chapter', () {
      final result = GetBibleAPI.parseReference("Genesis");
      expect(result, {
        "book_nr": null,
        "chapter": null,
        "start_verse": null,
        "end_verse": null,
      });
    });

    test('returns null values for invalid book name (book_nr null but matches structure)', () {
      final result = GetBibleAPI.parseReference("NonExistentBook 1:1");
      expect(result, {
        "book_nr": null, // book is not in the map
        "chapter": "1",
        "start_verse": "1",
        "end_verse": null,
      });
    });

    test('returns null values for malformed input (e.g. extra hyphens)', () {
      final result = GetBibleAPI.parseReference("John 3:16-18-20");
      expect(result, {
        "book_nr": null,
        "chapter": null,
        "start_verse": null,
        "end_verse": null,
      });
    });

    test('trims whitespace', () {
      final result = GetBibleAPI.parseReference("  John   3:16  ");
      expect(result, {
        "book_nr": "43",
        "chapter": "3",
        "start_verse": "16",
        "end_verse": null,
      });
    });

    test('is case insensitive for book names', () {
      final result = GetBibleAPI.parseReference("gEnEsIs 1");
      expect(result, {
        "book_nr": "1",
        "chapter": "1",
        "start_verse": null,
        "end_verse": null,
      });
    });
  });
}
