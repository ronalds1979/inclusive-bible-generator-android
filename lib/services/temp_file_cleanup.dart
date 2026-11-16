import 'dart:io';

String _normalizePath(String path) {
  final String normalized = path.replaceAll('\\', '/');
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

/// Deletes transient files in [dir] whose filename starts with [prefix] and
/// ends with [suffix] when they are older than [maxAge], skipping [excludePath].
Future<void> pruneTransientFiles(
  Directory dir, {
  required String prefix,
  required String suffix,
  Duration maxAge = const Duration(hours: 1),
  String? excludePath,
}) async {
  try {
    if (!await dir.exists()) return;
    final String? normalizedExclude = excludePath != null
        ? _normalizePath(excludePath)
        : null;
    final DateTime cutoff = DateTime.now().subtract(maxAge);
    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is! File) continue;
      if (normalizedExclude != null &&
          _normalizePath(entity.path) == normalizedExclude) {
        continue;
      }
      final String name = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : '';
      if (!name.startsWith(prefix) || !name.endsWith(suffix)) continue;
      try {
        final FileStat stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
        }
      } catch (_) {}
    }
  } catch (_) {}
}
