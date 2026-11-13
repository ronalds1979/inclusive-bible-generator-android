import 'package:flutter/material.dart';
import '../generator.dart';
import '../services/stock_photo_service.dart';

class StockPhotoSearchCard extends StatefulWidget {
  final String lang;
  final Generator generator;
  final StockPhotoService stockPhotoService;
  final ValueChanged<String> onPhotoSelected;

  const StockPhotoSearchCard({
    super.key,
    required this.lang,
    required this.generator,
    required this.stockPhotoService,
    required this.onPhotoSelected,
  });

  @override
  State<StockPhotoSearchCard> createState() => _StockPhotoSearchCardState();
}

class _StockPhotoSearchCardState extends State<StockPhotoSearchCard> {
  static const List<MapEntry<String, String>> _moodPresets = [
    MapEntry('stock_mood_sunrise', 'golden sunrise sky'),
    MapEntry('stock_mood_ocean', 'calm ocean horizon'),
    MapEntry('stock_mood_mountains', 'serene mountain landscape'),
    MapEntry('stock_mood_stars', 'starry night sky'),
    MapEntry('stock_mood_forest', 'peaceful misty forest'),
  ];

  final TextEditingController _searchController = TextEditingController();
  List<StockPhotoResult> _results = const [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _errorMessage;
  int? _downloadingIndex;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch([String? overrideQuery]) async {
    final String query = (overrideQuery ?? _searchController.text).trim();
    if (query.isEmpty) return;
    if (overrideQuery != null) {
      _searchController.text = overrideQuery;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final List<StockPhotoResult> fetched = await widget.stockPhotoService
          .searchPhotos(query);
      if (!mounted) return;
      setState(() {
        _results = fetched;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _errorMessage = widget.generator.getLocaleString(
          widget.lang,
          'stock_search_error',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _selectPhoto(int index) async {
    setState(() {
      _downloadingIndex = index;
      _errorMessage = null;
    });

    try {
      final String path = await widget.stockPhotoService.downloadPhotoToTemp(
        _results[index],
      );
      if (!mounted) return;
      widget.onPhotoSelected(path);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = widget.generator.getLocaleString(
          widget.lang,
          'stock_search_error',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _downloadingIndex = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String lang = widget.lang;
    final Generator generator = widget.generator;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_camera_back, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    generator.getLocaleString(lang, 'stock_search_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _moodPresets.map((preset) {
                return ActionChip(
                  label: Text(generator.getLocaleString(lang, preset.key)),
                  onPressed: _isSearching
                      ? null
                      : () => _runSearch(preset.value),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, child) {
                      return TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _runSearch(),
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: generator.getLocaleString(
                            lang,
                            'stock_search_hint',
                          ),
                          border: const OutlineInputBorder(),
                          suffixIcon: value.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  tooltip: generator.getLocaleString(
                                    lang,
                                    'clear_btn',
                                  ),
                                  onPressed: _searchController.clear,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, child) {
                    final bool isEmpty = value.text.trim().isEmpty;
                    return FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _isSearching || isEmpty ? null : _runSearch,
                      icon: _isSearching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search, size: 18),
                      label: Text(
                        generator.getLocaleString(lang, 'stock_search_btn'),
                      ),
                    );
                  },
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ] else if (_hasSearched && !_isSearching && _results.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                generator.getLocaleString(lang, 'stock_search_empty'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (_results.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final StockPhotoResult item = _results[index];
                    final bool isBusy = _downloadingIndex == index;
                    return Semantics(
                      button: true,
                      label: item.title,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _downloadingIndex != null
                            ? null
                            : () => _selectPhoto(index),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.thumbUrl,
                                width: 76,
                                height: 76,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 76,
                                  height: 76,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                            if (isBusy)
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
