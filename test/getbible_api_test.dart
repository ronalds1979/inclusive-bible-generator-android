import 'package:flutter_test/flutter_test.dart';
import '../lib/getbible_api.dart';

void main() {
  group('GetBibleAPI.parseReference', () {
    test('Happy path: Book and chapter only', () {
      final result = GetBibleAPI.parseReference('Genesis 1');
      expect(result, {
        'book_nr': '1',
        'chapter': '1',
        'start_verse': null,
        'end_verse': null,
      });
    });

    test('Happy path: Book, chapter and single verse', () {
      final result = GetBibleAPI.parseReference('John 3:16');
      expect(result, {
        'book_nr': '43',
        'chapter': '3',
        'start_verse': '16',
        'end_verse': null,
      });
    });

    test('Happy path: Book, chapter and verse range', () {
      final result = GetBibleAPI.parseReference('1 John 3:16-18');
      expect(result, {
        'book_nr': '62',
        'chapter': '3',
        'start_verse': '16',
        'end_verse': '18',
      });
    });

    test('Language variants: Portuguese', () {
      final result = GetBibleAPI.parseReference('João 1', lang: 'pt');
      expect(result, {
        'book_nr': '43',
        'chapter': '1',
        'start_verse': null,
        'end_verse': null,
      });
    });

    test('Language variants: Spanish', () {
      final result = GetBibleAPI.parseReference('1 Crónicas 1', lang: 'es');
      expect(result, {
        'book_nr': '13',
        'chapter': '1',
        'start_verse': null,
        'end_verse': null,
      });
    });

    test('Edge cases: Extra spaces and different cases', () {
      final result1 = GetBibleAPI.parseReference(' gEnEsIs   1 ');
      expect(result1, {
        'book_nr': '1',
        'chapter': '1',
        'start_verse': null,
        'end_verse': null,
      });
    });

    test('Edge cases: Book with multiple words', () {
      final result = GetBibleAPI.parseReference('Song of Solomon 1');
      expect(result, {
        'book_nr': '22',
        'chapter': '1',
        'start_verse': null,
        'end_verse': null,
      });
    });

    test('Error conditions: Missing chapter', () {
      final result = GetBibleAPI.parseReference('Genesis');
      expect(result, {
        'book_nr': null,
        'chapter': null,
        'start_verse': null,
        'end_verse': null,
      });
    });

    test('Error conditions: Invalid verse format', () {
      final result1 = GetBibleAPI.parseReference('Genesis 1:A');
      expect(result1, {
        'book_nr': null,
        'chapter': null,
        'start_verse': null,
        'end_verse': null,
      });

      final result2 = GetBibleAPI.parseReference('Genesis 1:1-2-3');
      expect(result2, {
        'book_nr': null,
        'chapter': null,
        'start_verse': null,
        'end_verse': null,
      });
    });

    test('Error conditions: Unknown book name', () {
      final result = GetBibleAPI.parseReference('RandomBook 1');
      // The regex will match RandomBook as a book name and 1 as a chapter.
      // But it won't be found in the mapping, so bookNr will be null.
      expect(result, {
        'book_nr': null,
        'chapter': '1',
        'start_verse': null,
        'end_verse': null,
      });
    });
  });
}
