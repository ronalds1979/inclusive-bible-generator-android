import 'package:flutter_test/flutter_test.dart';
import 'package:app/getbible_api.dart';

void main() {
  group('GetBibleAPI.parseReference', () {
    test('Basic chapter reference', () {
      final result = GetBibleAPI.parseReference('Genesis 1');
      expect(result['book_nr'], '1');
      expect(result['chapter'], '1');
      expect(result['start_verse'], null);
      expect(result['end_verse'], null);
    });

    test('Chapter and start verse', () {
      final result = GetBibleAPI.parseReference('Exodus 2:10');
      expect(result['book_nr'], '2');
      expect(result['chapter'], '2');
      expect(result['start_verse'], '10');
      expect(result['end_verse'], null);
    });

    test('Chapter, start verse and end verse', () {
      final result = GetBibleAPI.parseReference('John 3:16-18');
      expect(result['book_nr'], '43');
      expect(result['chapter'], '3');
      expect(result['start_verse'], '16');
      expect(result['end_verse'], '18');
    });

    test('Numbered books', () {
      final result = GetBibleAPI.parseReference('1 John 3');
      expect(result['book_nr'], '62');
      expect(result['chapter'], '3');
      expect(result['start_verse'], null);
      expect(result['end_verse'], null);

      final result2 = GetBibleAPI.parseReference('2 Corinthians 4:5-6');
      expect(result2['book_nr'], '47');
      expect(result2['chapter'], '4');
      expect(result2['start_verse'], '5');
      expect(result2['end_verse'], '6');
    });

    test('Books with non-ASCII characters (Portuguese)', () {
      final result = GetBibleAPI.parseReference('Gênesis 1', lang: 'pt');
      expect(result['book_nr'], '1');
      expect(result['chapter'], '1');
      expect(result['start_verse'], null);
      expect(result['end_verse'], null);

      final result2 = GetBibleAPI.parseReference('Êxodo 2:3', lang: 'pt');
      expect(result2['book_nr'], '2');
      expect(result2['chapter'], '2');
      expect(result2['start_verse'], '3');
      expect(result2['end_verse'], null);

      final result3 = GetBibleAPI.parseReference(
        '1 Crônicas 5:1-2',
        lang: 'pt',
      );
      expect(result3['book_nr'], '13');
      expect(result3['chapter'], '5');
      expect(result3['start_verse'], '1');
      expect(result3['end_verse'], '2');
    });

    test('Books with non-ASCII characters (Spanish)', () {
      final result = GetBibleAPI.parseReference('Génesis 1', lang: 'es');
      expect(result['book_nr'], '1');
      expect(result['chapter'], '1');
      expect(result['start_verse'], null);
      expect(result['end_verse'], null);

      final result2 = GetBibleAPI.parseReference('Éxodo 2:3', lang: 'es');
      expect(result2['book_nr'], '2');
      expect(result2['chapter'], '2');
      expect(result2['start_verse'], '3');
      expect(result2['end_verse'], null);

      final result3 = GetBibleAPI.parseReference(
        '1 Crónicas 5:1-2',
        lang: 'es',
      );
      expect(result3['book_nr'], '13');
      expect(result3['chapter'], '5');
      expect(result3['start_verse'], '1');
      expect(result3['end_verse'], '2');
    });

    test('Malformed references', () {
      // Missing chapter
      final result1 = GetBibleAPI.parseReference('Genesis');
      expect(result1['book_nr'], null);
      expect(result1['chapter'], null);

      // Random string
      final result2 = GetBibleAPI.parseReference('NotABook 1');
      expect(
        result2['book_nr'],
        null,
      ); // Regex might match but book won't be found
      expect(result2['chapter'], '1');

      // Invalid format with numbers at the start that don't match a numbered book
      final result3 = GetBibleAPI.parseReference('123 Genesis 1');
      expect(result3['book_nr'], null);

      // Book name with trailing spaces
      final result4 = GetBibleAPI.parseReference('Genesis   1');
      expect(result4['book_nr'], '1');
      expect(result4['chapter'], '1');

      // Completely garbage
      final result5 = GetBibleAPI.parseReference('!!! @@@');
      expect(result5['book_nr'], null);
      expect(result5['chapter'], null);
    });

    test('Case insensitivity', () {
      final result = GetBibleAPI.parseReference('gEnEsIs 1');
      expect(result['book_nr'], '1');
      expect(result['chapter'], '1');
    });
  });
}
