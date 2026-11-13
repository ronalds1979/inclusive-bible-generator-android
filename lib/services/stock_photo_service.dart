import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
  static const Map<String, String> _requestHeaders = {
    'User-Agent': 'InclusiveBibleGenerator/1.0 (https://github.com)',
  };

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

    final http.Response response = await _httpClient
        .get(uri, headers: _requestHeaders)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw HttpException('Stock photo search failed (${response.statusCode})');
    }

    final Map<String, dynamic> decoded =
        jsonDecode(response.body) as Map<String, dynamic>;
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
      if (resolvedUrl.isEmpty) continue;

      final String rawTitle = (pageValue['title'] as String? ?? '')
          .replaceFirst('File:', '')
          .replaceAll('_', ' ');

      results.add(
        StockPhotoResult(
          title: rawTitle,
          thumbUrl: thumbUrl ?? url ?? '',
          fullUrl: thumbUrl ?? url ?? '',
        ),
      );
    }
    return results;
  }

  /// Downloads [photo] to a temporary file and returns its local path.
  Future<String> downloadPhotoToTemp(StockPhotoResult photo) async {
    final Uri uri = Uri.parse(photo.fullUrl);
    final http.Response response = await _httpClient
        .get(uri, headers: _requestHeaders)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw HttpException(
        'Failed to download stock photo (${response.statusCode})',
      );
    }

    final Directory tempDir = await getTemporaryDirectory();
    final File outFile = File(
      '${tempDir.path}/stock_bg_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await outFile.writeAsBytes(response.bodyBytes, flush: true);
    return outFile.path;
  }
}
