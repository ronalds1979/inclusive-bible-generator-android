import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../widgets/verse_preview_card.dart';

/// Luminance summary sampled across the top, center, and bottom horizontal
/// bands of a background image.
@immutable
class BackgroundLuminanceProfile {
  final double top;
  final double center;
  final double bottom;

  const BackgroundLuminanceProfile({
    required this.top,
    required this.center,
    required this.bottom,
  });

  /// Returns the band luminance corresponding to the card's vertical offset.
  double luminanceForOffset(double yOffset) {
    if (yOffset < -55.0) return top;
    if (yOffset > 55.0) return bottom;
    return center;
  }

  /// Finds the vertical placement (`-110.0`, `0.0`, or `110.0`) with the
  /// highest WCAG 2.1 contrast ratio for [fontColor] at the given [dim].
  ({double yOffset, double ratio}) bestPlacementFor({
    required Color fontColor,
    required double dim,
  }) {
    final double fgLum = fontColor.computeLuminance();
    final List<(double, double)> candidates = [
      (0.0, center),
      (-110.0, top),
      (110.0, bottom),
    ];
    double bestOffset = 0.0;
    double bestRatio = -1.0;
    for (final (offset, bandLum) in candidates) {
      final double effectiveBg = (bandLum * (1.0 - dim)).clamp(0.0, 1.0);
      final double ratio = VersePreviewCard.computeWcagContrastRatio(
        fgLum,
        effectiveBg,
      );
      if (ratio > bestRatio) {
        bestRatio = ratio;
        bestOffset = offset;
      }
    }
    return (yOffset: bestOffset, ratio: bestRatio);
  }
}

/// Samples actual pixel luminance from a background image (asset or file)
/// using a tiny downsampled decode for fast, accurate WCAG contrast checks.
class ContrastSampler {
  const ContrastSampler();

  static double _srgbChannelToLinear(int channel8) {
    final double c = channel8 / 255.0;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Computes W3C relative luminance from 8-bit RGB channels.
  @visibleForTesting
  static double relativeLuminanceFromRgb(int r, int g, int b) {
    return 0.2126 * _srgbChannelToLinear(r) +
        0.7152 * _srgbChannelToLinear(g) +
        0.0722 * _srgbChannelToLinear(b);
  }

  /// Computes top/center/bottom band luminances from raw RGBA bytes.
  @visibleForTesting
  static BackgroundLuminanceProfile profileFromRgba({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
  }) {
    if (width <= 0 || height <= 0 || rgbaBytes.length < width * height * 4) {
      return const BackgroundLuminanceProfile(
        top: 0.26,
        center: 0.26,
        bottom: 0.26,
      );
    }

    final int band1End = (height / 3).floor().clamp(1, height);
    final int band2End = ((height * 2) / 3).floor().clamp(band1End, height);

    double topSum = 0;
    int topCount = 0;
    double centerSum = 0;
    int centerCount = 0;
    double bottomSum = 0;
    int bottomCount = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int idx = (y * width + x) * 4;
        final double lum = relativeLuminanceFromRgb(
          rgbaBytes[idx],
          rgbaBytes[idx + 1],
          rgbaBytes[idx + 2],
        );
        if (y < band1End) {
          topSum += lum;
          topCount++;
        } else if (y < band2End) {
          centerSum += lum;
          centerCount++;
        } else {
          bottomSum += lum;
          bottomCount++;
        }
      }
    }

    return BackgroundLuminanceProfile(
      top: topCount > 0 ? topSum / topCount : 0.26,
      center: centerCount > 0 ? centerSum / centerCount : 0.26,
      bottom: bottomCount > 0 ? bottomSum / bottomCount : 0.26,
    );
  }

  Future<BackgroundLuminanceProfile?> sampleImageBytes(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(bytes, targetWidth: 48);
      final ui.FrameInfo frame = await codec.getNextFrame();
      image = frame.image;
      final ByteData? rgba = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (rgba == null) return null;
      return profileFromRgba(
        rgbaBytes: rgba.buffer.asUint8List(),
        width: image.width,
        height: image.height,
      );
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  Future<BackgroundLuminanceProfile?> sampleFile(String path) async {
    try {
      final File file = File(path);
      if (!await file.exists()) return null;
      final Uint8List bytes = await file.readAsBytes();
      return await sampleImageBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<BackgroundLuminanceProfile?> sampleAsset(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      return await sampleImageBytes(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}
