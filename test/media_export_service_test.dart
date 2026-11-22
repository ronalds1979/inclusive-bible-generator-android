import 'dart:io';
import 'package:app/services/media_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  late Directory tempDir;
  late File fakePng;
  late File fakeWav;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('media_export_test_');
    fakePng = File('${tempDir.path}/verse_1.png');
    await fakePng.writeAsBytes(List<int>.filled(256, 0x42));
    fakeWav = File('${tempDir.path}/verse_audio_1.wav');
    await fakeWav.writeAsBytes(List<int>.filled(2048, 0x11));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MediaExportService.buildShareFiles', () {
    test('shares a single image/png when audioPath is null', () async {
      bool muxCalled = false;
      final MediaExportService service = MediaExportService(
        muxVideoOverride: ({
          required String imagePath,
          required String audioPath,
          required String outputPath,
        }) async {
          muxCalled = true;
          return outputPath;
        },
        saveVideoOverride: (_) async {},
        isAndroidOverride: true,
      );

      final List<XFile> files = await service.buildShareFiles(
        imagePath: fakePng.path,
        tempDir: tempDir,
        audioPath: null,
        timestamp: 100,
      );

      expect(muxCalled, isFalse);
      expect(files, hasLength(1));
      expect(files.first.path, equals(fakePng.path));
      expect(files.first.mimeType, equals('image/png'));
    });

    test(
      'muxes image + WAV audio into a single video/mp4 so WhatsApp receives both image and audio',
      () async {
        String? savedVideoPath;
        String? receivedImagePath;
        String? receivedAudioPath;

        final MediaExportService service = MediaExportService(
          muxVideoOverride: ({
            required String imagePath,
            required String audioPath,
            required String outputPath,
          }) async {
            receivedImagePath = imagePath;
            receivedAudioPath = audioPath;
            final File mp4 = File(outputPath);
            await mp4.writeAsBytes(List<int>.filled(4096, 0x22));
            return outputPath;
          },
          saveVideoOverride: (String path) async {
            savedVideoPath = path;
          },
          isAndroidOverride: true,
        );

        final List<XFile> files = await service.buildShareFiles(
          imagePath: fakePng.path,
          tempDir: tempDir,
          audioPath: fakeWav.path,
          timestamp: 200,
        );

        expect(receivedImagePath, equals(fakePng.path));
        expect(receivedAudioPath, equals(fakeWav.path));
        expect(files, hasLength(1));
        expect(files.first.mimeType, equals('video/mp4'));
        expect(files.first.path, endsWith('verse_video_200.mp4'));
        expect(savedVideoPath, equals(files.first.path));
      },
    );

    test(
      'falls back to single image/png (never mixed image + wav) when muxing fails',
      () async {
        bool saveVideoCalled = false;
        final MediaExportService service = MediaExportService(
          muxVideoOverride: ({
            required String imagePath,
            required String audioPath,
            required String outputPath,
          }) async => null,
          saveVideoOverride: (_) async {
            saveVideoCalled = true;
          },
          isAndroidOverride: true,
        );

        final List<XFile> files = await service.buildShareFiles(
          imagePath: fakePng.path,
          tempDir: tempDir,
          audioPath: fakeWav.path,
          timestamp: 300,
        );

        expect(saveVideoCalled, isFalse);
        expect(files, hasLength(1));
        expect(files.first.path, equals(fakePng.path));
        expect(files.first.mimeType, equals('image/png'));
      },
    );

    test('skips muxing when WAV file is missing or header-only', () async {
      bool muxCalled = false;
      final File emptyWav = File('${tempDir.path}/empty.wav');
      await emptyWav.writeAsBytes(List<int>.filled(44, 0));

      final MediaExportService service = MediaExportService(
        muxVideoOverride: ({
          required String imagePath,
          required String audioPath,
          required String outputPath,
        }) async {
          muxCalled = true;
          return outputPath;
        },
        saveVideoOverride: (_) async {},
        isAndroidOverride: true,
      );

      final List<XFile> files = await service.buildShareFiles(
        imagePath: fakePng.path,
        tempDir: tempDir,
        audioPath: emptyWav.path,
        timestamp: 400,
      );

      expect(muxCalled, isFalse);
      expect(files, hasLength(1));
      expect(files.first.path, equals(fakePng.path));
      expect(files.first.mimeType, equals('image/png'));
    });
  });
}
