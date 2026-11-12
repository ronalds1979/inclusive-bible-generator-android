import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app/gemini_service.dart';

void main() {
  group('GeminiService tests', () {
    test(
      'buildBackgroundPrompt includes verse, reference, style, and no-text instruction',
      () {
        final prompt = GeminiService.buildBackgroundPrompt(
          verse: 'Your word is a lamp to my feet and a light to my path.',
          reference: 'Psalm 119:105',
          styleKey: 'style_watercolor',
          customPrompt: 'warm lantern on a stone path at dusk',
        );

        expect(prompt, contains('Psalm 119:105'));
        expect(
          prompt,
          contains('Your word is a lamp to my feet and a light to my path.'),
        );
        expect(prompt, contains('watercolor'));
        expect(prompt, contains('warm lantern on a stone path at dusk'));
        expect(prompt, contains('Do NOT include any text'));
      },
    );

    test(
      'extractImageBytesFromResponse parses steps.model_output.content image block',
      () {
        final sampleBytes = Uint8List.fromList([
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ]);
        final b64 = base64Encode(sampleBytes);

        final responseMap = {
          "id": "int_123",
          "steps": [
            {
              "type": "model_output",
              "status": "done",
              "content": [
                {"type": "text", "text": "Generated background:"},
                {"type": "image", "mime_type": "image/png", "data": b64},
              ],
            },
          ],
        };

        final extracted = GeminiService.extractImageBytesFromResponse(
          responseMap,
        );
        expect(extracted, isNotNull);
        expect(extracted, equals(sampleBytes));
      },
    );

    test(
      'extractImageBytesFromResponse parses top-level output_image convenience field',
      () {
        final sampleBytes = Uint8List.fromList([1, 2, 3, 4]);
        final b64 = base64Encode(sampleBytes);

        final responseMap = {
          "id": "int_456",
          "output_image": {"mime_type": "image/png", "data": b64},
        };

        final extracted = GeminiService.extractImageBytesFromResponse(
          responseMap,
        );
        expect(extracted, isNotNull);
        expect(extracted, equals(sampleBytes));
      },
    );

    test(
      'extractImageBytesFromResponse returns null when no image is present',
      () {
        final responseMap = {
          "id": "int_789",
          "steps": [
            {
              "type": "model_output",
              "content": [
                {"type": "text", "text": "No image generated"},
              ],
            },
          ],
        };

        expect(
          GeminiService.extractImageBytesFromResponse(responseMap),
          isNull,
        );
      },
    );

    test(
      'extractApiKeyFromText detects valid AIza API keys inside clipboard text',
      () {
        final validKey = 'AIza${List.filled(33, 'x').join()}';
        expect(
          GeminiService.extractApiKeyFromText('My key is $validKey!'),
          equals(validKey),
        );
        expect(GeminiService.extractApiKeyFromText('no key here'), isNull);
        expect(GeminiService.extractApiKeyFromText(null), isNull);
      },
    );

    test(
      'generateBackgroundImage sends x-goog-api-key and Interactions API request and returns decoded image bytes',
      () async {
        final expectedBytes = Uint8List.fromList([10, 20, 30, 40]);
        late http.Request capturedRequest;

        final mockClient = MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              "id": "int_mock_1",
              "steps": [
                {
                  "type": "model_output",
                  "status": "done",
                  "content": [
                    {
                      "type": "image",
                      "mime_type": "image/png",
                      "data": base64Encode(expectedBytes),
                    },
                  ],
                },
              ],
            }),
            200,
          );
        });

        final service = GeminiService(httpClient: mockClient);
        final result = await service.generateBackgroundImage(
          apiKey: 'mock-gemini-key-for-unit-test',
          verse: 'In the beginning God created the heavens and the earth.',
          reference: 'Genesis 1:1',
          aspectRatio: '3:4',
          styleKey: 'style_cinematic',
          customPrompt: 'starry cosmos',
        );

        expect(result, equals(expectedBytes));
        expect(capturedRequest.url.toString(), GeminiService.endpoint);
        expect(
          capturedRequest.headers['x-goog-api-key'],
          'mock-gemini-key-for-unit-test',
        );
        expect(
          capturedRequest.headers['Api-Revision'],
          GeminiService.apiRevision,
        );

        final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
        expect(body['model'], 'gemini-nano-banana-2.1');
        expect(body['response_format']['type'], 'image');
        expect(body['response_format']['aspect_ratio'], '3:4');
        expect(body['response_format']['image_size'], '1K');
      },
    );

    test(
      'generateBackgroundImage falls back to Free-Tier Gemini Flash scene renderer when raster image models return HTTP 429',
      () async {
        final List<String> requestedModels = [];

        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final model = body['model'] as String;
          requestedModels.add(model);

          if (model.contains('image') || model.contains('banana')) {
            return http.Response(
              jsonEncode({
                "error": {
                  "message":
                      "Rate limit exceeded for model $model (limit: 0 requests per day on Free Tier).",
                  "code": "too_many_requests",
                },
              }),
              429,
            );
          }

          // Free-Tier text model (`gemini-3.8-flash`) returns scene JSON
          return http.Response(
            jsonEncode({
              "id": "int_scene_1",
              "steps": [
                {
                  "type": "model_output",
                  "status": "done",
                  "content": [
                    {
                      "type": "text",
                      "text": jsonEncode({
                        "skyColors": [
                          "#0F2027",
                          "#203A43",
                          "#2C5364",
                          "#F4A261",
                        ],
                        "glowColor": "#FFE599",
                        "celestialType": "sun",
                        "lightX": 0.5,
                        "lightY": 0.3,
                        "rayCount": 12,
                        "landscapeType": "mountains",
                        "layerColors": [
                          "#2B4162",
                          "#1B2A4A",
                          "#121C33",
                          "#0A101F",
                        ],
                        "bokehCount": 20,
                        "seed": 777,
                      }),
                    },
                  ],
                },
              ],
            }),
            200,
          );
        });

        final service = GeminiService(httpClient: mockClient);
        final pngBytes = await service.generateBackgroundImage(
          apiKey: 'mock-gemini-key-for-unit-test',
          verse: 'The Lord is my shepherd; I shall not want.',
          reference: 'Psalm 23:1',
          aspectRatio: '1:1',
          styleKey: 'style_cinematic',
        );

        expect(pngBytes, isNotNull);
        expect(pngBytes!.length, greaterThan(100));
        // PNG magic header bytes: 137 80 78 71
        expect(pngBytes.sublist(0, 4), equals([137, 80, 78, 71]));
        expect(requestedModels, contains('gemini-nano-banana-2.1'));
        expect(requestedModels, contains('gemini-3.8-flash'));
      },
    );

    test(
      'caches zero-quota image keys and skips raster image models on subsequent calls',
      () async {
        final requestedModels = <String>[];
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final model = body['model'] as String;
          requestedModels.add(model);

          if (model != 'gemini-3.8-flash') {
            return http.Response(
              jsonEncode({
                'error': {'message': 'Quota exceeded, limit: 0'}
              }),
              429,
            );
          }

          return http.Response(
            jsonEncode({
              'outputs': [
                {
                  'type': 'text',
                  'text': jsonEncode({
                    'skyTop': '#102030',
                    'skyBottom': '#405060',
                    'accent': '#F0D080',
                    'mood': 'dawn',
                    'elements': ['hills', 'rays'],
                  }),
                }
              ]
            }),
            200,
          );
        });

        final service = GeminiService(httpClient: mockClient);
        const testKey = 'mock-zero-quota-key-123';

        final firstBytes = await service.generateBackgroundImage(
          apiKey: testKey,
          verse: 'Be still',
          reference: 'Psalm 46:10',
        );
        expect(firstBytes, isNotNull);
        expect(requestedModels, contains('gemini-nano-banana-2.1'));
        expect(requestedModels, contains('gemini-3.8-flash'));

        requestedModels.clear();

        final secondBytes = await service.generateBackgroundImage(
          apiKey: testKey,
          verse: 'The Lord is my shepherd',
          reference: 'Psalm 23:1',
        );
        expect(secondBytes, isNotNull);
        expect(requestedModels, equals(['gemini-3.8-flash']));
      },
    );

    test(
      'aborts fallback immediately on 401 without trying remaining models',
      () async {
        final requestedModels = <String>[];
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final model = body['model'] as String;
          requestedModels.add(model);

          if (model == 'gemini-nano-banana-2.1') {
            return http.Response('Model unavailable', 404);
          }

          return http.Response(
            jsonEncode({
              'error': {'message': 'API_KEY_INVALID'}
            }),
            401,
          );
        });

        final service = GeminiService(httpClient: mockClient);
        final result = await service.generateBackgroundImage(
          apiKey: 'mock-invalid-key-401',
          verse: 'In the beginning',
          reference: 'Genesis 1:1',
        );
        expect(result, isNull);
        // Should have tried primary, then first fallback, and stopped immediately on 401
        expect(requestedModels.length, equals(2));
        expect(requestedModels, isNot(contains('gemini-3.8-flash')));
      },
    );
  });
}
