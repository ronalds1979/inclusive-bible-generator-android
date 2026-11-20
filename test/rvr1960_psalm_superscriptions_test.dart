import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app/getbible_api.dart';

void main() {
  setUp(() {
    GetBibleAPI.clearChapterCache();
  });

  test(
    'RVR1960 Psalm 46:1 prepends missing superscription from bolls.life',
    () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://bolls.life/get-text/RV1960/19/46/');
        return http.Response(
          jsonEncode([
            {
              'pk': 1458964,
              'verse': 1,
              'text':
                  'Dios es nuestro amparo y fortaleza,<br> Nuestro pronto auxilio en las tribulaciones.',
            },
            {
              'pk': 1458965,
              'verse': 2,
              'text':
                  'Por tanto, no temeremos, aunque la tierra sea removida,<br> Y se traspasen los montes al corazón del mar;',
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final v1 = await GetBibleAPI.getPassage(
        'rv1960',
        'Salmos 46:1',
        lang: 'es',
        httpClient: mockClient,
      );
      expect(
        v1,
        'Al músico principal; de los hijos de Coré. Salmo sobre Alamot.\n'
        'Dios es nuestro amparo y fortaleza, Nuestro pronto auxilio en las tribulaciones.',
      );

      final v2 = await GetBibleAPI.getPassage(
        'rv1960',
        'Salmos 46:2',
        lang: 'es',
        httpClient: mockClient,
      );
      expect(
        v2,
        'Por tanto, no temeremos, aunque la tierra sea removida, Y se traspasen los montes al corazón del mar;',
      );

      final range = await GetBibleAPI.getPassage(
        'rv1960',
        'Salmos 46:1-2',
        lang: 'es',
        httpClient: mockClient,
      );
      expect(
        range,
        'Al músico principal; de los hijos de Coré. Salmo sobre Alamot.\n'
        'Dios es nuestro amparo y fortaleza, Nuestro pronto auxilio en las tribulaciones. '
        'Por tanto, no temeremos, aunque la tierra sea removida, Y se traspasen los montes al corazón del mar;',
      );
    },
  );

  test(
    'RVR1960 Psalm 46:1 does not duplicate superscription if already returned',
    () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'pk': 1458964,
              'verse': 1,
              'text':
                  'Al músico principal; de los hijos de Coré. Salmo sobre Alamot. Dios es nuestro amparo y fortaleza.',
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final v1 = await GetBibleAPI.getPassage(
        'rv1960',
        'Salmos 46:1',
        lang: 'es',
        httpClient: mockClient,
      );
      expect(
        v1,
        'Al músico principal; de los hijos de Coré. Salmo sobre Alamot. Dios es nuestro amparo y fortaleza.',
      );
    },
  );

  test(
    'RVR1960 Psalm 1:1 (no superscription) and non-RVR1960 versions remain unchanged',
    () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/RV1960/19/1/')) {
          return http.Response(
            jsonEncode([
              {
                'pk': 1,
                'verse': 1,
                'text': 'Bienaventurado el varón que no anduvo en consejo de malos.',
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode([
            {
              'pk': 2,
              'verse': 1,
              'text': 'God is our refuge and strength, a very present help in trouble.',
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final ps1 = await GetBibleAPI.getPassage(
        'rv1960',
        'Salmos 1:1',
        lang: 'es',
        httpClient: mockClient,
      );
      expect(ps1, 'Bienaventurado el varón que no anduvo en consejo de malos.');

      final esvPs46 = await GetBibleAPI.getPassage(
        'esv',
        'Psalms 46:1',
        lang: 'en',
        httpClient: mockClient,
      );
      expect(
        esvPs46,
        'God is our refuge and strength, a very present help in trouble.',
      );
    },
  );
}
