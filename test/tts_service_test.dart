import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/tts_service.dart';

void main() {
  group('TtsService resolveVoiceConfig tests', () {
    test('resolves Portuguese Female and Male voices', () {
      expect(TtsService.resolveVoiceConfig('pt-BR', 'Female'), {
        'name': 'pt-BR-FranciscaNeural',
        'locale': 'pt-BR',
      });
      expect(TtsService.resolveVoiceConfig('pt-BR', 'Male'), {
        'name': 'pt-BR-AntonioNeural',
        'locale': 'pt-BR',
      });
    });

    test('resolves English Female and Male voices', () {
      expect(TtsService.resolveVoiceConfig('en', 'Female'), {
        'name': 'en-US-JennyNeural',
        'locale': 'en-US',
      });
      expect(TtsService.resolveVoiceConfig('en', 'Male'), {
        'name': 'en-US-GuyNeural',
        'locale': 'en-US',
      });
    });

    test('resolves Spanish Female and Male voices', () {
      expect(TtsService.resolveVoiceConfig('es', 'Female'), {
        'name': 'es-ES-ElviraNeural',
        'locale': 'es-ES',
      });
      expect(TtsService.resolveVoiceConfig('es', 'Male'), {
        'name': 'es-ES-AlvaroNeural',
        'locale': 'es-ES',
      });
    });
  });
}
