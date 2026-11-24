import 'dart:typed_data';
import 'dart:ui' as ui;

const int maxImageDimension = 16384;
const int maxImagePixels = 64000000;

/// Returns true when raster image dimensions are positive and bounded against pixel-bomb OOMs.
bool isSafeImageDimensions(int width, int height) {
  if (width <= 0 || height <= 0) return false;
  if (width > maxImageDimension || height > maxImageDimension) return false;
  return width <= maxImagePixels ~/ height;
}

/// Inspects an encoded image header without decoding pixels and checks dimension bounds.
Future<bool> hasSafeImageDimensionsFile(String path) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromFilePath(path);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    return isSafeImageDimensions(descriptor.width, descriptor.height);
  } catch (_) {
    return false;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}

/// Verifies PNG, JPEG, or WebP raster image magic bytes before decoding/saving.
bool isValidRasterImageBytes(Uint8List bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return true;
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return true;
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return true;
  }
  return false;
}
