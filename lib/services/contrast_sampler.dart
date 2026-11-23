import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../widgets/verse_preview_card.dart';
import 'image_validation.dart';

/// Luminance & representative color summary sampled across the top, center,
/// and bottom horizontal bands of a background image.
@immutable
class BackgroundLuminanceProfile {
  final double top;
  final double center;
  final double bottom;
  final double? topP10;
  final double? topP90;
  final double? centerP10;
  final double? centerP90;
  final double? bottomP10;
  final double? bottomP90;
  final ui.Color? topColor;
  final ui.Color? centerColor;
  final ui.Color? bottomColor;

  const BackgroundLuminanceProfile({
    required this.top,
    required this.center,
    required this.bottom,
    this.topP10,
    this.topP90,
    this.centerP10,
    this.centerP90,
    this.bottomP10,
    this.bottomP90,
    this.topColor,
    this.centerColor,
    this.bottomColor,
  });

  /// Returns the mean band luminance corresponding to the card's vertical offset.
  double luminanceForOffset(double yOffset) {
    if (yOffset < -55.0) return top;
    if (yOffset > 55.0) return bottom;
    return center;
  }

  /// Returns the worst-case band luminance (10th percentile for dark text,
  /// 90th percentile for light text) so high-contrast scenes (e.g. bright sky +
  /// dark trees) do not falsely report safe contrast.
  double worstCaseLuminanceFor(double yOffset, double fgLuminance) {
    final bool isLightText = fgLuminance >= 0.4;
    if (yOffset < -55.0) {
      return (isLightText ? topP90 : topP10) ?? top;
    }
    if (yOffset > 55.0) {
      return (isLightText ? bottomP90 : bottomP10) ?? bottom;
    }
    return (isLightText ? centerP90 : centerP10) ?? center;
  }

  /// Returns the representative RGB color for the band corresponding to [yOffset].
  ui.Color? colorForOffset(double yOffset) {
    if (yOffset < -55.0) return topColor;
    if (yOffset > 55.0) return bottomColor;
    return centerColor;
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
  static const int maxImageBytes = 20 * 1024 * 1024;
  static const int _maxAssetCacheEntries = 64;

  // ⚡ Bolt: Precompute the 256-entry sRGB-to-linear LUT once instead of invoking
  // math.pow() ~7,000 times per sampled image.
  static final Float64List _srgbToLinearLut = Float64List.fromList(
    List<double>.generate(256, (int channel8) {
      final double c = channel8 / 255.0;
      return c <= 0.03928
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }, growable: false),
  );

  static final Map<String, BackgroundLuminanceProfile> _assetProfileCache =
      <String, BackgroundLuminanceProfile>{};

  const ContrastSampler();

  static double _srgbChannelToLinear(int channel8) {
    return _srgbToLinearLut[channel8.clamp(0, 255)];
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

    final List<double> topLums = <double>[];
    final List<double> centerLums = <double>[];
    final List<double> bottomLums = <double>[];

    double topSum = 0;
    int topR = 0, topG = 0, topB = 0;
    double centerSum = 0;
    int centerR = 0, centerG = 0, centerB = 0;
    double bottomSum = 0;
    int bottomR = 0, bottomG = 0, bottomB = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int idx = (y * width + x) * 4;
        final int r = rgbaBytes[idx];
        final int g = rgbaBytes[idx + 1];
        final int b = rgbaBytes[idx + 2];
        final double lum = relativeLuminanceFromRgb(r, g, b);
        if (y < band1End) {
          topSum += lum;
          topR += r;
          topG += g;
          topB += b;
          topLums.add(lum);
        } else if (y < band2End) {
          centerSum += lum;
          centerR += r;
          centerG += g;
          centerB += b;
          centerLums.add(lum);
        } else {
          bottomSum += lum;
          bottomR += r;
          bottomG += g;
          bottomB += b;
          bottomLums.add(lum);
        }
      }
    }

    double? percentile(List<double> values, double p) {
      if (values.isEmpty) return null;
      values.sort();
      final int index = ((values.length - 1) * p).round().clamp(
        0,
        values.length - 1,
      );
      return values[index];
    }

    ui.Color? meanColor(int rSum, int gSum, int bSum, int count) {
      if (count <= 0) return null;
      return ui.Color.fromARGB(
        255,
        (rSum / count).round().clamp(0, 255),
        (gSum / count).round().clamp(0, 255),
        (bSum / count).round().clamp(0, 255),
      );
    }

    return BackgroundLuminanceProfile(
      top: topLums.isNotEmpty ? topSum / topLums.length : 0.26,
      center: centerLums.isNotEmpty ? centerSum / centerLums.length : 0.26,
      bottom: bottomLums.isNotEmpty ? bottomSum / bottomLums.length : 0.26,
      topP10: percentile(topLums, 0.10),
      topP90: percentile(topLums, 0.90),
      centerP10: percentile(centerLums, 0.10),
      centerP90: percentile(centerLums, 0.90),
      bottomP10: percentile(bottomLums, 0.10),
      bottomP90: percentile(bottomLums, 0.90),
      topColor: meanColor(topR, topG, topB, topLums.length),
      centerColor: meanColor(centerR, centerG, centerB, centerLums.length),
      bottomColor: meanColor(bottomR, bottomG, bottomB, bottomLums.length),
    );
  }

  Future<BackgroundLuminanceProfile?> sampleImageBytes(Uint8List bytes) async {
    // 🛡️ Sentinel: Bound image byte payloads and verify PNG/JPEG/WebP magic bytes before native codec decoding
    if (bytes.isEmpty ||
        bytes.length > maxImageBytes ||
        !isValidRasterImageBytes(bytes)) {
      return null;
    }
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
      // 🛡️ Sentinel: Enforce 20 MB size limit and raster magic bytes before reading full file into memory
      final int fileSize = await file.length();
      if (fileSize <= 0 || fileSize > maxImageBytes) return null;
      final List<int> headerBytes = await file
          .openRead(0, 12)
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
      if (!isValidRasterImageBytes(Uint8List.fromList(headerBytes))) {
        return null;
      }
      final Uint8List bytes = await file.readAsBytes();
      return await sampleImageBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<BackgroundLuminanceProfile?> sampleAsset(String assetPath) async {
    // ⚡ Bolt: Built-in background assets are immutable, so caching their sampled
    // luminance profiles skips repeated rootBundle loads, Skia decodes, and pixel scans.
    final BackgroundLuminanceProfile? cached = _assetProfileCache[assetPath];
    if (cached != null) return cached;
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final BackgroundLuminanceProfile? profile = await sampleImageBytes(
        data.buffer.asUint8List(),
      );
      if (profile != null) {
        if (_assetProfileCache.length >= _maxAssetCacheEntries) {
          _assetProfileCache.remove(_assetProfileCache.keys.first);
        }
        _assetProfileCache[assetPath] = profile;
      }
      return profile;
    } catch (_) {
      return null;
    }
  }
}
