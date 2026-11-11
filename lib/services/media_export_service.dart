import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class MediaExportService {
  Future<void> captureSaveAndShareImage({
    required GlobalKey boundaryKey,
    required String altText,
    required String caption,
    String? audioPath,
  }) async {
    try {
      final RenderObject? renderObject = boundaryKey.currentContext
          ?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return;

      final ui.Image image = await renderObject.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final String directory = (await getApplicationDocumentsDirectory()).path;
      final File imgFile = File(
        '$directory/verse_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await imgFile.writeAsBytes(pngBytes);

      final bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }
      await Gal.putImage(imgFile.path, album: 'Inclusive Bible');

      final List<XFile> filesToShare = [XFile(imgFile.path)];
      // ⚡ Bolt: Avoid synchronous I/O on main thread
      if (audioPath != null && await File(audioPath).exists()) {
        filesToShare.add(XFile(audioPath));
      }

      await SharePlus.instance.share(
        ShareParams(files: filesToShare, text: "$altText\n\n$caption"),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error capturing image: $e");
      }
    }
  }
}
