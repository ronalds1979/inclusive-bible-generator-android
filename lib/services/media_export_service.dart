import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'temp_file_cleanup.dart';

typedef VideoMuxCallback = Future<String?> Function({
  required String imagePath,
  required String audioPath,
  required String outputPath,
});

typedef ShareFilesCallback = Future<void> Function(
  List<XFile> files,
  String text,
);

typedef SaveMediaCallback = Future<void> Function(String path);

class MediaExportService {
  static const MethodChannel _muxerChannel = MethodChannel(
    'com.ronalds1979.inclusivebible/media_muxer',
  );

  /// Minimum valid WAV file length (44-byte RIFF/WAVE header + audio data).
  static const int _minValidWavBytes = 44;

  /// Minimum valid MP4 file length to confirm muxing produced media data.
  static const int _minValidMp4Bytes = 1024;

  final VideoMuxCallback? _muxVideoOverride;
  final ShareFilesCallback? _shareFilesOverride;
  final SaveMediaCallback? _saveImageOverride;
  final SaveMediaCallback? _saveVideoOverride;
  final Future<Directory> Function()? _tempDirProvider;
  final bool? _isAndroidOverride;

  const MediaExportService({
    @visibleForTesting VideoMuxCallback? muxVideoOverride,
    @visibleForTesting ShareFilesCallback? shareFilesOverride,
    @visibleForTesting SaveMediaCallback? saveImageOverride,
    @visibleForTesting SaveMediaCallback? saveVideoOverride,
    @visibleForTesting Future<Directory> Function()? tempDirProvider,
    @visibleForTesting bool? isAndroidOverride,
  }) : _muxVideoOverride = muxVideoOverride,
       _shareFilesOverride = shareFilesOverride,
       _saveImageOverride = saveImageOverride,
       _saveVideoOverride = saveVideoOverride,
       _tempDirProvider = tempDirProvider,
       _isAndroidOverride = isAndroidOverride;

  Future<String?> _muxImageAndAudio({
    required String imagePath,
    required String audioPath,
    required String outputPath,
  }) async {
    if (_muxVideoOverride != null) {
      return _muxVideoOverride(
        imagePath: imagePath,
        audioPath: audioPath,
        outputPath: outputPath,
      );
    }
    if (!(_isAndroidOverride ?? Platform.isAndroid)) {
      return null;
    }
    try {
      final String? result = await _muxerChannel.invokeMethod<String>(
        'muxImageAndAudio',
        {
          'imagePath': imagePath,
          'audioPath': audioPath,
          'outputPath': outputPath,
        },
      );
      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error muxing image + TTS audio into MP4: $e");
      }
      return null;
    }
  }

  /// Prepares the single media attachment to share alongside [altText] and
  /// [caption].
  ///
  /// Messaging apps like WhatsApp drop all attachments when receiving mixed
  /// MIME types (`image/png` + `audio/wav` via `ACTION_SEND_MULTIPLE` / `*/*`).
  /// When TTS audio is included, this method muxes the still verse image and
  /// WAV audio into a single H.264/AAC MP4 (`video/mp4`) so apps share the
  /// visual verse card, playable audio narration, and text caption together.
  /// If muxing is unavailable or fails, it falls back to sharing the PNG image
  /// alone rather than sending a broken mixed-type batch.
  @visibleForTesting
  Future<List<XFile>> buildShareFiles({
    required String imagePath,
    required Directory tempDir,
    String? audioPath,
    int? timestamp,
  }) async {
    if (audioPath != null) {
      final File audioFile = File(audioPath);
      if (await audioFile.exists() &&
          await audioFile.length() > _minValidWavBytes) {
        final int ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
        final String videoPath = '${tempDir.path}/verse_video_$ts.mp4';
        final String? muxedPath = await _muxImageAndAudio(
          imagePath: imagePath,
          audioPath: audioPath,
          outputPath: videoPath,
        );
        if (muxedPath != null) {
          final File videoFile = File(muxedPath);
          if (await videoFile.exists() &&
              await videoFile.length() > _minValidMp4Bytes) {
            try {
              if (_saveVideoOverride != null) {
                await _saveVideoOverride(muxedPath);
              } else {
                await Gal.putVideo(muxedPath, album: 'Inclusive Bible');
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint("Error saving video to gallery: $e");
              }
            }
            return [XFile(muxedPath, mimeType: 'video/mp4')];
          }
        }
      }
    }

    return [XFile(imagePath, mimeType: 'image/png')];
  }

  Future<bool> captureSaveAndShareImage({
    required GlobalKey boundaryKey,
    required String altText,
    required String caption,
    String? audioPath,
  }) async {
    try {
      final RenderObject? renderObject = boundaryKey.currentContext
          ?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return false;

      final ui.Image image = await renderObject.toImage(pixelRatio: 3.0);
      final ByteData? byteData;
      try {
        byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
      } finally {
        // ⚡ Bolt: Release native GPU/Skia image buffer immediately after PNG encoding
        image.dispose();
      }
      if (byteData == null) return false;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final Directory tempDir =
          await (_tempDirProvider ?? getTemporaryDirectory)();
      final int timestamp = DateTime.now().millisecondsSinceEpoch;
      final File imgFile = File(
        '${tempDir.path}/verse_$timestamp.png',
      );
      await imgFile.writeAsBytes(pngBytes);

      if (_saveImageOverride != null) {
        await _saveImageOverride(imgFile.path);
      } else {
        final bool hasAccess = await Gal.hasPermission(toAlbum: true);
        if (!hasAccess) {
          await Gal.requestPermission(toAlbum: true);
        }
        await Gal.putImage(imgFile.path, album: 'Inclusive Bible');
      }

      final List<XFile> filesToShare = await buildShareFiles(
        imagePath: imgFile.path,
        tempDir: tempDir,
        audioPath: audioPath,
        timestamp: timestamp,
      );

      final String shareText = "$altText\n\n$caption";
      if (_shareFilesOverride != null) {
        await _shareFilesOverride(filesToShare, shareText);
      } else {
        await SharePlus.instance.share(
          ShareParams(files: filesToShare, text: shareText),
        );
      }

      // ⚡ Bolt: Defer transient file cleanup until after share sheet opens so directory I/O is off the critical path
      await Future.wait([
        pruneTransientFiles(
          tempDir,
          prefix: 'verse_',
          suffix: '.png',
          excludePath: imgFile.path,
        ),
        pruneTransientFiles(
          tempDir,
          prefix: 'verse_video_',
          suffix: '.mp4',
          excludePath: filesToShare.first.path,
        ),
      ]);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error capturing image: $e");
      }
      return false;
    }
  }
}
