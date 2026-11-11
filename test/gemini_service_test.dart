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
      'generateBackgroundImage sends correct Interactions API request and returns decoded image bytes',
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
          apiKey: 'test-api-key-123',
          verse: 'In the beginning God created the heavens and the earth.',
          reference: 'Genesis 1:1',
          aspectRatio: '3:4',
          styleKey: 'style_cinematic',
          customPrompt: 'starry cosmos',
        );

        expect(result, equals(expectedBytes));
        expect(capturedRequest.url.toString(), GeminiService.endpoint);
        expect(capturedRequest.headers['x-goog-api-key'], 'test-api-key-123');
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
  });
}
