import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Availability state of Android's on-device ML Kit GenAI Image Description
/// API (powered by Gemini Nano via AICore).
enum GeminiNanoAvailability {
  available,
  downloadable,
  downloading,
  unavailable;

  /// Returns `true` when the device hardware/OS supports Gemini Nano
  /// (ready now, downloadable on demand, or currently downloading).
  bool get isCompatible => this != GeminiNanoAvailability.unavailable;

  static GeminiNanoAvailability fromChannelValue(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'available':
        return GeminiNanoAvailability.available;
      case 'downloadable':
        return GeminiNanoAvailability.downloadable;
      case 'downloading':
        return GeminiNanoAvailability.downloading;
      default:
        return GeminiNanoAvailability.unavailable;
    }
  }
}

class GeminiNanoDescriptionResult {
  final String? description;
  final String? errorCode;

  const GeminiNanoDescriptionResult({this.description, this.errorCode});

  bool get isSuccess => description != null && description!.trim().isNotEmpty;
}

/// Flutter bridge for Android's on-device Gemini Nano image description
/// (`com.google.mlkit:genai-image-description`).
/// Runs 100% locally at zero cost with no API key on compatible devices.
class GeminiNanoService {
  static const MethodChannel _defaultChannel = MethodChannel(
    'com.ronalds1979.inclusivebible/gemini_nano',
  );

  final MethodChannel _channel;
  final bool? _isAndroidOverride;

  const GeminiNanoService({
    MethodChannel? channel,
    @visibleForTesting bool? isAndroidOverride,
  }) : _channel = channel ?? _defaultChannel,
       _isAndroidOverride = isAndroidOverride;

  bool get _isAndroid => _isAndroidOverride ?? (!kIsWeb && Platform.isAndroid);

  /// Checks whether the current device supports on-device Gemini Nano image
  /// description. Always returns [GeminiNanoAvailability.unavailable] on
  /// non-Android platforms or unsupported devices.
  Future<GeminiNanoAvailability> checkAvailability() async {
    if (!_isAndroid) {
      return GeminiNanoAvailability.unavailable;
    }
    try {
      final String? status = await _channel.invokeMethod<String>(
        'checkAvailability',
      );
      return GeminiNanoAvailability.fromChannelValue(status);
    } on MissingPluginException {
      return GeminiNanoAvailability.unavailable;
    } on PlatformException {
      return GeminiNanoAvailability.unavailable;
    } catch (_) {
      return GeminiNanoAvailability.unavailable;
    }
  }

  /// Generates an on-device Alt-Text description from raw image bytes
  /// (for example, a built-in background asset).
  Future<GeminiNanoDescriptionResult> describeImageBytes(
    Uint8List imageBytes,
  ) async {
    if (!_isAndroid) {
      return const GeminiNanoDescriptionResult(errorCode: 'unavailable');
    }
    return _invokeDescribe({'imageBytes': imageBytes});
  }

  /// Generates an on-device Alt-Text description from a local image file path
  /// (for example, a stock photo or custom gallery image).
  Future<GeminiNanoDescriptionResult> describeImageFile(
    String imagePath,
  ) async {
    if (!_isAndroid) {
      return const GeminiNanoDescriptionResult(errorCode: 'unavailable');
    }
    return _invokeDescribe({'imagePath': imagePath});
  }

  Future<GeminiNanoDescriptionResult> _invokeDescribe(
    Map<String, Object> arguments,
  ) async {
    try {
      final String? result = await _channel.invokeMethod<String>(
        'describeImage',
        arguments,
      );
      final String trimmed = (result ?? '').trim();
      if (trimmed.isEmpty) {
        return const GeminiNanoDescriptionResult(errorCode: 'empty_result');
      }
      return GeminiNanoDescriptionResult(description: trimmed);
    } on PlatformException catch (e) {
      return GeminiNanoDescriptionResult(errorCode: e.code);
    } on MissingPluginException {
      return const GeminiNanoDescriptionResult(errorCode: 'unavailable');
    } catch (_) {
      return const GeminiNanoDescriptionResult(errorCode: 'inference_error');
    }
  }
}
