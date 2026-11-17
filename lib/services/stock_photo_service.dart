import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'temp_file_cleanup.dart';

class StockPhotoResult {
  final String title;
  final String thumbUrl;
  final String fullUrl;

  const StockPhotoResult({
    required this.title,
    required this.thumbUrl,
    required this.fullUrl,
  });
}

class StockPhotoService {
  static const String _commonsApiBase = 'https://commons.wikimedia.org/w/api.php';
  static const int maxDownloadBytes = 20 * 1024 * 1024;
  static const int maxApiBytes = 2 * 1024 * 1024;
  static const int _maxRedirects = 3;
  static const Set<String> _allowedHosts = {
    'upload.wikimedia.org',
    'commons.wikimedia.org',
  };
  static const Map<String, String> _requestHeaders = {
    'User-Agent': 'InclusiveBibleGenerator/1.0 (https://github.com)',
  };

  /// Parses [rawUrl] and returns it only if it uses HTTPS and an allowlisted
  /// Wikimedia host.
  static Uri? parseAllowedWikimediaUri(String rawUrl) {
    final Uri? uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasScheme || uri.scheme.toLowerCase() != 'https') {
      return null;
    }
    if (!_allowedHosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    return uri;
  }

  static final http.Client _sharedHttpClient = http.Client();

  final http.Client _httpClient;
  final bool _ownsClient;

  StockPhotoService({http.Client? httpClient})
    : _httpClient = httpClient ?? _sharedHttpClient,
      _ownsClient = false;

  void close() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }

  /// Searches Wikimedia Commons for free bitmap photography matching [query].
  Future<List<StockPhotoResult>> searchPhotos(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final Uri uri = Uri.parse(_commonsApiBase).replace(
      queryParameters: {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': '$trimmed filetype:bitmap',
        'gsrnamespace': '6',
        'gsrlimit': '10',
        'prop': 'imageinfo',
        'iiprop': 'url|mime',
        'iiurlwidth': '1080',
        'format': 'json',
        'origin': '*',
      },
    );

    final http.Request request = http.Request('GET', uri)
      ..headers.addAll(_requestHeaders)
      ..followRedirects = false;
    final http.StreamedResponse streamedResponse = await _httpClient
        .send(request)
        .timeout(const Duration(seconds: 12));

    if (streamedResponse.statusCode != 200) {
      await streamedResponse.stream.drain<void>().catchError((_) {});
      throw HttpException('Stock photo search failed (${streamedResponse.statusCode})');
    }

    final int? contentLength = streamedResponse.contentLength;
    if (contentLength != null && contentLength > maxApiBytes) {
      await streamedResponse.stream.drain<void>().catchError((_) {});
      throw const HttpException('Stock photo search response exceeds 2 MB limit');
    }

    final BytesBuilder apiBuilder = BytesBuilder(copy: false);
    await for (final List<int> chunk in streamedResponse.stream.timeout(
      const Duration(seconds: 12),
    )) {
      if (apiBuilder.length + chunk.length > maxApiBytes) {
        throw const HttpException('Stock photo search response exceeds 2 MB limit');
      }
      apiBuilder.add(chunk);
    }

    final Map<String, dynamic> decoded =
        jsonDecode(utf8.decode(apiBuilder.takeBytes())) as Map<String, dynamic>;
    final Map<String, dynamic>? queryObj =
        decoded['query'] as Map<String, dynamic>?;
    final Map<String, dynamic>? pages =
        queryObj?['pages'] as Map<String, dynamic>?;
    if (pages == null || pages.isEmpty) return const [];

    final List<StockPhotoResult> results = [];
    for (final dynamic pageValue in pages.values) {
      if (pageValue is! Map<String, dynamic>) continue;
      final List<dynamic>? infoList = pageValue['imageinfo'] as List<dynamic>?;
      if (infoList == null || infoList.isEmpty) continue;
      final Map<String, dynamic> info = infoList.first as Map<String, dynamic>;
      final String mime = (info['mime'] as String? ?? '').toLowerCase();
      if (mime != 'image/jpeg' && mime != 'image/png') continue;

      final String? thumbUrl = info['thumburl'] as String?;
      final String? url = info['url'] as String?;
      final String resolvedUrl = thumbUrl ?? url ?? '';
      if (resolvedUrl.isEmpty || parseAllowedWikimediaUri(resolvedUrl) == null) {
        continue;
      }

      final String rawTitle = (pageValue['title'] as String? ?? '')
          .replaceFirst('File:', '')
          .replaceAll('_', ' ');

      results.add(
        StockPhotoResult(
          title: rawTitle,
          thumbUrl: resolvedUrl,
          fullUrl: resolvedUrl,
        ),
      );
    }
    return results;
  }

  /// Downloads [photo] to a temporary file and returns its local path.
  Future<String> downloadPhotoToTemp(StockPhotoResult photo) async {
    Uri? currentUri = parseAllowedWikimediaUri(photo.fullUrl);
    if (currentUri == null) {
      throw const HttpException('Disallowed stock photo URL');
    }

    http.StreamedResponse? streamedResponse;
    for (int hop = 0; hop <= _maxRedirects; hop++) {
      final http.Request request = http.Request('GET', currentUri!)
        ..headers.addAll(_requestHeaders)
        ..followRedirects = false;
      streamedResponse = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 15));

      final int code = streamedResponse.statusCode;
      if (code == 301 || code == 302 || code == 303 || code == 307 || code == 308) {
        await streamedResponse.stream.drain<void>().catchError((_) {});
        if (hop == _maxRedirects) {
          throw const HttpException('Too many redirects while downloading stock photo');
        }
        final String? location = streamedResponse.headers['location'];
        if (location == null || location.trim().isEmpty) {
          throw const HttpException('Redirect response missing Location header');
        }
        final Uri resolved = currentUri.resolve(location.trim());
        final Uri? validatedRedirect = parseAllowedWikimediaUri(resolved.toString());
        if (validatedRedirect == null) {
          throw const HttpException('Disallowed stock photo redirect URL');
        }
        currentUri = validatedRedirect;
        continue;
      }
      break;
    }

    if (streamedResponse == null || streamedResponse.statusCode != 200) {
      await streamedResponse?.stream.drain<void>().catchError((_) {});
      throw HttpException(
        'Failed to download stock photo (${streamedResponse?.statusCode ?? 0})',
      );
    }

    final int? contentLength = streamedResponse.contentLength;
    if (contentLength != null && contentLength > maxDownloadBytes) {
      await streamedResponse.stream.drain<void>().catchError((_) {});
      throw const HttpException('Stock photo exceeds 20 MB size limit');
    }

    final BytesBuilder builder = BytesBuilder(copy: false);
    await for (final List<int> chunk in streamedResponse.stream.timeout(
      const Duration(seconds: 15),
    )) {
      if (builder.length + chunk.length > maxDownloadBytes) {
        throw const HttpException('Stock photo exceeds 20 MB size limit');
      }
      builder.add(chunk);
    }

    final Uint8List bytes = builder.takeBytes();
    if (bytes.isEmpty) {
      throw const HttpException('Failed to download stock photo (empty body)');
    }

    final bool isJpeg =
        bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    final bool isPng =
        bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    if (!isJpeg && !isPng) {
      throw const HttpException('Downloaded file is not a valid JPEG or PNG image');
    }

    final Directory tempDir = await getTemporaryDirectory();
    await pruneTransientFiles(tempDir, prefix: 'stock_bg_', suffix: '.jpg');
    final File outFile = File(
      '${tempDir.path}/stock_bg_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await outFile.writeAsBytes(bytes, flush: true);
    return outFile.path;
  }
}
