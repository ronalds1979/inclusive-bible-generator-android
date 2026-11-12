import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'book_mapping.dart';
import 'gemini_service.dart';
import 'generator.dart';
import 'getbible_api.dart';
import 'services/media_export_service.dart';
import 'services/tts_service.dart';
import 'widgets/gemini_auth_dialog.dart';
import 'widgets/gemini_background_card.dart';
import 'widgets/verse_preview_card.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final Generator? generator;
  final GeminiService? geminiService;
  final TtsService? ttsService;
  final MediaExportService? mediaExportService;

  const MyApp({
    super.key,
    this.generator,
    this.geminiService,
    this.ttsService,
    this.mediaExportService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inclusive Bible Generator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: MyHomePage(
        generator: generator,
        geminiService: geminiService,
        ttsService: ttsService,
        mediaExportService: mediaExportService,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final Generator? generator;
  final GeminiService? geminiService;
  final TtsService? ttsService;
  final MediaExportService? mediaExportService;

  const MyHomePage({
    super.key,
    this.generator,
    this.geminiService,
    this.ttsService,
    this.mediaExportService,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const List<MapEntry<Color, String>> _presetColors = [
    MapEntry(Colors.white, "color_white"),
    MapEntry(Color(0xFFFFD54F), "color_gold"),
    MapEntry(Color(0xFFFFF8E1), "color_cream"),
    MapEntry(Color(0xFF81D4FA), "color_sky_blue"),
    MapEntry(Color(0xFFFFAB91), "color_coral"),
    MapEntry(Colors.black, "color_black"),
  ];

  String? _copiedField;
  Timer? _copyFeedbackTimer;
  final ScrollController _workspaceScrollController = ScrollController();

  static const List<String> _stepTabKeys = [
    "tab_verse",
    "tab_background",
    "tab_style",
    "tab_audio",
  ];

  late final Generator generator;
  late final GeminiService geminiService;
  late final TtsService ttsService;
  late final MediaExportService mediaExportService;
  final GlobalKey _globalKey = GlobalKey();

  int _selectedTabIndex = 0;

  String currentLang = "Português (Brasil)";
  final List<String> languages = const [
    "Português (Brasil)",
    "English (US/UK)",
    "Español (España)",
  ];

  String bibleLang = "pt";
  String youVersionApiKey = GetBibleAPI.defaultYouVersionApiKey;

  List<String> bibleVersions = ["-"];
  String selectedBibleVersion = "-";
  Map<String, String> bibleVersionsMap = {};

  String? selectedBook;
  int selectedChapter = 119;
  int selectedVerse = 105;
  int? selectedEndVerse;
  final TextEditingController referenceController = TextEditingController();
  final TextEditingController verseController = TextEditingController();
  final TextEditingController geminiPromptController = TextEditingController();

  String selectedBackground = "default.png";
  List<String> backgrounds = ["default.png"];
  String? customImagePath;

  String? geminiApiKey;
  String selectedGeminiStyle = GeminiService.styleKeys.first;
  bool isGeneratingGeminiBg = false;
  bool isGeminiBackground = false;

  Color fontColor = Colors.white;
  double fontSize = 60.0;
  String aspectRatioStr = "1:1";
  double yOffset = 0.0;

  bool generateAudio = false;
  bool isPlayingAudioPreview = false;
  String gender = "Female";
  final List<String> genders = const ["Female", "Male"];

  String altText = "";
  String caption = "";
  String statusMessage = "";
  bool isError = false;
  bool isSuccess = false;

  // ⚡ Bolt: Cache status flags during state updates to avoid repeated
  // expensive string computations (.toLowerCase().contains()) on every UI rebuild.
  void _updateStatus(String msg, {bool? forceError, bool? forceSuccess}) {
    statusMessage = msg;
    final lowerMsg = msg.toLowerCase();
    isError =
        forceError ??
        (lowerMsg.contains("error") ||
            lowerMsg.contains("erro") ||
            lowerMsg.contains("falha") ||
            lowerMsg.contains("falló"));
    isSuccess =
        forceSuccess ??
        (lowerMsg.contains("success") ||
            lowerMsg.contains("sucesso") ||
            lowerMsg.contains("conectada") ||
            lowerMsg.contains("connected") ||
            lowerMsg.contains("éxito"));
  }

  bool isLoading = true;
  bool isFetching = false;
  bool isGenerating = false;
  late final Listenable _previewListenable;

  @override
  void initState() {
    super.initState();
    generator = widget.generator ?? Generator();
    geminiService = widget.geminiService ?? GeminiService();
    ttsService = widget.ttsService ?? TtsService();
    mediaExportService = widget.mediaExportService ?? MediaExportService();
    _previewListenable = Listenable.merge([
      referenceController,
      verseController,
    ]);
    _initApp();
  }

  @override
  void dispose() {
    _copyFeedbackTimer?.cancel();
    _workspaceScrollController.dispose();
    referenceController.dispose();
    verseController.dispose();
    geminiPromptController.dispose();
    ttsService.stop();
    super.dispose();
  }

  Future<void> _initApp() async {
    // ⚡ Bolt: Parallelize independent startup I/O (locales, secure storage keys, asset manifest)
    final results = await Future.wait<dynamic>([
      generator.loadLocales(),
      geminiService.loadApiKey(),
      GetBibleAPI.loadYouVersionApiKey(),
      _loadBackgrounds(),
    ]);
    geminiApiKey = results[1] as String?;
    youVersionApiKey =
        (results[2] as String?) ?? GetBibleAPI.defaultYouVersionApiKey;
    _syncDefaultBookForLanguage();
    await _loadBibleVersions();
    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
  }

  void _syncDefaultBookForLanguage() {
    final List<String> books = getCanonicalBooks(bibleLang);
    if (books.isNotEmpty) {
      // Translate current selectedBook's canonical number if possible
      int targetIndex = 18; // Default to Psalms (book 19, index 18)
      if (selectedBook != null) {
        for (final prefix in ["pt", "en", "es"]) {
          final int? nr = bookMapping[prefix]?[selectedBook!];
          if (nr != null && nr >= 1 && nr <= books.length) {
            targetIndex = nr - 1;
            break;
          }
        }
      }
      selectedBook = books.length > targetIndex
          ? books[targetIndex]
          : books.first;
      if (referenceController.text.trim().isNotEmpty) {
        _applyQuickReferenceSelector();
      }
    }
  }

  void _clampChapterAndVerse() {
    final int maxChapters = getChapterCountForBook(selectedBook, bibleLang);
    if (selectedChapter < 1 || selectedChapter > maxChapters) {
      selectedChapter = 1;
    }
    final int maxVerses = getVerseCountForChapter(
      selectedBook,
      selectedChapter,
      bibleLang,
    );
    if (selectedVerse < 1 || selectedVerse > maxVerses) {
      selectedVerse = 1;
    }
    if (selectedEndVerse != null &&
        (selectedEndVerse! <= selectedVerse || selectedEndVerse! > maxVerses)) {
      selectedEndVerse = null;
    }
  }

  void _applyQuickReferenceSelector() {
    if (selectedBook == null || selectedBook!.isEmpty) return;
    _clampChapterAndVerse();
    final String versePart = selectedEndVerse != null
        ? "$selectedVerse-$selectedEndVerse"
        : "$selectedVerse";
    referenceController.text = "$selectedBook $selectedChapter:$versePart";
  }

  Future<void> _loadBackgrounds() async {
    try {
      final AssetManifest assetManifest =
          await AssetManifest.loadFromAssetBundle(rootBundle);
      backgrounds = assetManifest
          .listAssets()
          .where(
            (String key) =>
                key.contains('assets/backgrounds/') &&
                !key.contains('.DS_Store'),
          )
          .map((e) => e.split('/').last)
          .toList();
      if (backgrounds.isEmpty) backgrounds = ["default.png"];
      selectedBackground = backgrounds.first;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error loading backgrounds: $e");
      }
      backgrounds = ["default.png"];
      selectedBackground = "default.png";
    }
  }

  String getLangKey() {
    if (currentLang.contains("English")) return "en";
    if (currentLang.contains("Español")) return "es";
    return "pt-BR";
  }

  String getAudioLangKey() {
    if (bibleLang == "en") return "en";
    if (bibleLang == "es") return "es";
    return "pt-BR";
  }

  Future<void> _loadBibleVersions() async {
    setState(() {
      _updateStatus("Loading Bible versions...");
    });

    final versions = await GetBibleAPI.getVersions(
      lang: bibleLang,
      youVersionApiKey: youVersionApiKey,
    );
    if (versions.isNotEmpty) {
      bibleVersionsMap = {for (var v in versions) v["name"]!: v["id"]!};
      bibleVersions = bibleVersionsMap.keys.toList();
      selectedBibleVersion = bibleVersions.first;
      setState(() {
        _updateStatus("");
      });
    } else {
      setState(() {
        bibleVersions = ["-"];
        selectedBibleVersion = "-";
        _updateStatus("Error loading versions.", forceError: true);
      });
    }
  }

  Future<void> _fetchVerse() async {
    if (referenceController.text.trim().isEmpty) {
      _applyQuickReferenceSelector();
    }
    final String reference = referenceController.text.trim();
    if (selectedBibleVersion == "-" || reference.isEmpty) {
      setState(() {
        _updateStatus("Please provide Version, and Reference.");
      });
      return;
    }

    final String? bibleId = bibleVersionsMap[selectedBibleVersion];
    if (bibleId == null) return;

    setState(() {
      isFetching = true;
      _updateStatus("Fetching verse...");
    });

    final String? content = await GetBibleAPI.getPassage(
      bibleId,
      reference,
      lang: bibleLang,
      youVersionApiKey: youVersionApiKey,
    );
    if (content != null) {
      final Map<String, String> previewTexts = await generator.generateTexts(
        getLangKey(),
        content,
        reference,
      );
      setState(() {
        isFetching = false;
        verseController.text = content;
        altText = previewTexts["altText"]!;
        caption = previewTexts["caption"]!;
        _updateStatus("Verse fetched successfully.", forceSuccess: true);
      });
    } else {
      setState(() {
        isFetching = false;
        _updateStatus(
          "Error fetching verse. Check reference format.",
          forceError: true,
        );
      });
    }
  }

  Future<void> _fetchVerseOfTheDay() async {
    final String? bibleId = bibleVersionsMap[selectedBibleVersion];
    if (bibleId == null || selectedBibleVersion == "-") return;

    setState(() {
      isFetching = true;
      _updateStatus("Fetching Verse of the Day...");
    });

    final Map<String, String>? votd = await GetBibleAPI.getVerseOfTheDay(
      lang: bibleLang,
      bibleId: bibleId,
      youVersionApiKey: youVersionApiKey,
    );

    if (votd != null) {
      final String content = votd["text"]!;
      final String reference = votd["reference"]!;
      final Map<String, String> previewTexts = await generator.generateTexts(
        getLangKey(),
        content,
        reference,
      );
      setState(() {
        isFetching = false;
        selectedBook = votd["book"];
        selectedChapter = int.tryParse(votd["chapter"] ?? "1") ?? 1;
        final List<String> verseParts = (votd["verse"] ?? "1").split('-');
        selectedVerse = int.tryParse(verseParts.first) ?? 1;
        selectedEndVerse = verseParts.length > 1
            ? int.tryParse(verseParts.last)
            : null;
        _clampChapterAndVerse();
        referenceController.text = reference;
        verseController.text = content;
        altText = previewTexts["altText"]!;
        caption = previewTexts["caption"]!;
        _updateStatus("Verse of the Day loaded!", forceSuccess: true);
      });
    } else {
      setState(() {
        isFetching = false;
        _updateStatus("Error loading Verse of the Day.", forceError: true);
      });
    }
  }

  Future<void> _selectCustomImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // 🛡️ Sentinel: Validate file size (max 20MB) to prevent Memory Exhaustion DoS in UI rendering
      final int fileSize = await File(image.path).length();
      if (fileSize > 20 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image file exceeds 20MB limit.')),
        );
        return;
      }

      setState(() {
        customImagePath = image.path;
        isGeminiBackground = false;
      });
    }
  }

  Future<bool> _showGeminiAuthDialog() async {
    final String lang = getLangKey();
    final bool? connected = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return GeminiAuthDialog(
          lang: lang,
          generator: generator,
          initialApiKey: geminiApiKey,
          onSave: (String entered) async {
            await geminiService.saveApiKey(entered);
            setState(() {
              geminiApiKey = entered.isNotEmpty ? entered : null;
              _updateStatus(
                entered.isNotEmpty
                    ? generator.getLocaleString(lang, "gemini_key_saved_msg")
                    : generator.getLocaleString(lang, "gemini_key_removed_msg"),
                forceSuccess: entered.isNotEmpty,
              );
            });
          },
          onDisconnect: () async {
            await geminiService.saveApiKey("");
            setState(() {
              geminiApiKey = null;
              _updateStatus(
                generator.getLocaleString(lang, "gemini_key_removed_msg"),
              );
            });
          },
        );
      },
    );
    return connected ?? false;
  }

  Future<void> _generateGeminiBackground() async {
    final String verse = verseController.text.trim();
    final String reference = referenceController.text.trim();
    final String lang = getLangKey();

    if (verse.isEmpty) return;

    // Auto-detect from clipboard first if not connected yet
    if (geminiApiKey == null || geminiApiKey!.isEmpty) {
      final String? clipKey = await geminiService.detectApiKeyFromClipboard();
      if (clipKey != null && clipKey.isNotEmpty) {
        await geminiService.saveApiKey(clipKey);
        setState(() {
          geminiApiKey = clipKey;
          _updateStatus(
            generator.getLocaleString(lang, "gemini_clipboard_detected_msg"),
            forceSuccess: true,
          );
        });
      } else {
        final bool connected = await _showGeminiAuthDialog();
        if (!connected || geminiApiKey == null || geminiApiKey!.isEmpty) {
          return;
        }
      }
    }

    setState(() {
      isGeneratingGeminiBg = true;
      _updateStatus(generator.getLocaleString(lang, "gemini_generating_msg"));
    });

    final Uint8List? imageBytes = await geminiService.generateBackgroundImage(
      apiKey: geminiApiKey!,
      verse: verse,
      reference: reference,
      aspectRatio: aspectRatioStr,
      styleKey: selectedGeminiStyle,
      customPrompt: geminiPromptController.text.trim(),
    );

    if (imageBytes != null) {
      try {
        final directory = (await getApplicationDocumentsDirectory()).path;
        final File bgFile = File(
          '$directory/gemini_bg_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await bgFile.writeAsBytes(imageBytes, flush: true);

        setState(() {
          customImagePath = bgFile.path;
          isGeminiBackground = true;
          isGeneratingGeminiBg = false;
          _updateStatus(
            generator.getLocaleString(lang, "gemini_bg_success_msg"),
            forceSuccess: true,
          );
        });
      } catch (e) {
        if (kDebugMode) {
          debugPrint("Error saving Gemini background image: $e");
        }
        setState(() {
          isGeneratingGeminiBg = false;
          _updateStatus(
            generator.getLocaleString(lang, "gemini_bg_error_msg"),
            forceError: true,
          );
        });
      }
    } else {
      final String baseErr = generator.getLocaleString(
        lang,
        "gemini_bg_error_msg",
      );
      final String detail = geminiService.lastError != null
          ? " (${geminiService.lastError})"
          : "";
      final bool isInvalidKey =
          geminiService.lastError != null &&
          (geminiService.lastError!.contains("API key not valid") ||
              geminiService.lastError!.contains("API_KEY_INVALID") ||
              geminiService.lastError!.contains("HTTP 401") ||
              geminiService.lastError!.contains("HTTP 403"));
      if (isInvalidKey) {
        await geminiService.saveApiKey("");
      }
      setState(() {
        if (isInvalidKey) {
          geminiApiKey = null;
        }
        isGeneratingGeminiBg = false;
        _updateStatus("$baseErr$detail", forceError: true);
      });
    }
  }

  Future<void> _toggleAudioPreview() async {
    if (isPlayingAudioPreview) {
      await ttsService.stop();
      setState(() {
        isPlayingAudioPreview = false;
      });
      return;
    }

    final String verse = verseController.text.trim();
    if (verse.isEmpty) return;

    setState(() {
      isPlayingAudioPreview = true;
    });
    await ttsService.speakPreview(
      verse: verse,
      reference: referenceController.text.trim(),
      lang: getAudioLangKey(),
      gender: gender,
    );
    if (mounted) {
      setState(() {
        isPlayingAudioPreview = false;
      });
    }
  }

  Future<void> _generateContent() async {
    final String verse = verseController.text.trim();
    final String reference = referenceController.text.trim();

    if (verse.isEmpty || reference.isEmpty) return;

    setState(() {
      isGenerating = true;
      _updateStatus("Generating content...");
    });

    final String lang = getLangKey();
    String? customDescription;
    if (isGeminiBackground && customImagePath != null) {
      final String styleLabel = generator.getLocaleString(
        lang,
        selectedGeminiStyle,
      );
      final String extraDetails = geminiPromptController.text.trim();
      customDescription = extraDetails.isNotEmpty
          ? "AI-generated background ($styleLabel: $extraDetails)."
          : "AI-generated background ($styleLabel).";
    }
    final Map<String, String> texts = await generator.generateTexts(
      lang,
      verse,
      reference,
      customDescription: customDescription,
    );
    setState(() {
      altText = texts["altText"]!;
      caption = texts["caption"]!;
    });

    String? audioPath;
    if (generateAudio) {
      audioPath = await ttsService.generateAudio(
        verse: verse,
        reference: reference,
        lang: getAudioLangKey(),
        gender: gender,
      );
    }

    await mediaExportService.captureSaveAndShareImage(
      boundaryKey: _globalKey,
      altText: altText,
      caption: caption,
      audioPath: audioPath,
    );

    setState(() {
      isGenerating = false;
      _updateStatus(
        generator.getLocaleString(lang, "success_msg"),
        forceSuccess: true,
      );
    });
  }

  void _copyToClipboard(String text, {String? fieldKey}) {
    Clipboard.setData(ClipboardData(text: text));
    if (fieldKey != null) {
      _copyFeedbackTimer?.cancel();
      setState(() => _copiedField = fieldKey);
      _copyFeedbackTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _copiedField = null);
        }
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          generator.getLocaleString(getLangKey(), "copy_success_msg"),
        ),
      ),
    );
  }

  Future<void> _showBookSearchSheet(
    String lang,
    List<String> canonicalBooks,
  ) async {
    final TextEditingController searchController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final String query = searchController.text.trim().toLowerCase();
            final List<String> filtered = query.isEmpty
                ? canonicalBooks
                : canonicalBooks
                    .where((b) => b.toLowerCase().contains(query))
                    .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.45,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: generator.getLocaleString(
                            lang,
                            "search_book_hint",
                          ),
                          border: const OutlineInputBorder(),
                          suffixIcon: query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  tooltip: generator.getLocaleString(
                                    lang,
                                    "clear_btn",
                                  ),
                                  onPressed: () {
                                    searchController.clear();
                                    setSheetState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final String book = filtered[index];
                            final bool isSelected = book == selectedBook;
                            return ListTile(
                              title: Text(
                                book,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  selectedBook = book;
                                  selectedChapter = 1;
                                  selectedVerse = 1;
                                  selectedEndVerse = null;
                                  _applyQuickReferenceSelector();
                                });
                                Navigator.of(sheetContext).pop();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
    searchController.dispose();
  }

  Widget _buildVerseTab(String lang) {
    final List<String> canonicalBooks = getCanonicalBooks(bibleLang);
    if (selectedBook == null || !canonicalBooks.contains(selectedBook)) {
      selectedBook = canonicalBooks.length > 18
          ? canonicalBooks[18]
          : canonicalBooks.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bible Text Language selector
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              generator.getLocaleString(lang, "bible_lang_label"),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            ChoiceChip(
              label: const Text("Português"),
              selected: bibleLang == "pt",
              visualDensity: VisualDensity.compact,
              onSelected: (selected) {
                if (selected && bibleLang != "pt") {
                  setState(() {
                    bibleLang = "pt";
                    _syncDefaultBookForLanguage();
                    _loadBibleVersions();
                  });
                }
              },
            ),
            ChoiceChip(
              label: const Text("English"),
              selected: bibleLang == "en",
              visualDensity: VisualDensity.compact,
              onSelected: (selected) {
                if (selected && bibleLang != "en") {
                  setState(() {
                    bibleLang = "en";
                    _syncDefaultBookForLanguage();
                    _loadBibleVersions();
                  });
                }
              },
            ),
            ChoiceChip(
              label: const Text("Español"),
              selected: bibleLang == "es",
              visualDensity: VisualDensity.compact,
              onSelected: (selected) {
                if (selected && bibleLang != "es") {
                  setState(() {
                    bibleLang = "es";
                    _syncDefaultBookForLanguage();
                    _loadBibleVersions();
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Text(
              generator.getLocaleString(lang, "bible_version_label"),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: DropdownButton<String>(
                isExpanded: true,
                value: selectedBibleVersion,
                items: bibleVersions
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(v, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => selectedBibleVersion = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Interactive Book -> Chapter -> Verse dropdown selector row
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 6.0,
            ),
            child: Builder(
              builder: (context) {
                final int maxChapters = getChapterCountForBook(
                  selectedBook,
                  bibleLang,
                );
                if (selectedChapter < 1 || selectedChapter > maxChapters) {
                  selectedChapter = 1;
                }
                final int maxVerses = getVerseCountForChapter(
                  selectedBook,
                  selectedChapter,
                  bibleLang,
                );
                if (selectedVerse < 1 || selectedVerse > maxVerses) {
                  selectedVerse = 1;
                }
                if (selectedEndVerse != null &&
                    (selectedEndVerse! <= selectedVerse ||
                        selectedEndVerse! > maxVerses)) {
                  selectedEndVerse = null;
                }

                return Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          label: generator.getLocaleString(lang, "book_label"),
                          child: DropdownButton<String>(
                            value: selectedBook,
                            items: canonicalBooks
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(b),
                                  ),
                                )
                                .toList(),
                            onChanged: (b) {
                              setState(() {
                                selectedBook = b;
                                selectedChapter = 1;
                                selectedVerse = 1;
                                selectedEndVerse = null;
                                _applyQuickReferenceSelector();
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search, size: 20),
                          tooltip: generator.getLocaleString(
                            lang,
                            "search_book_tooltip",
                          ),
                          onPressed: () =>
                              _showBookSearchSheet(lang, canonicalBooks),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${generator.getLocaleString(lang, "chapter_label")}: ",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Semantics(
                          label: generator.getLocaleString(
                            lang,
                            "chapter_label",
                          ),
                          child: DropdownButton<int>(
                            value: selectedChapter,
                            menuMaxHeight: 320,
                            items: List<DropdownMenuItem<int>>.generate(
                              maxChapters,
                              (i) => DropdownMenuItem<int>(
                                value: i + 1,
                                child: Text("${i + 1}"),
                              ),
                            ),
                            onChanged: (ch) {
                              if (ch != null) {
                                setState(() {
                                  selectedChapter = ch;
                                  selectedVerse = 1;
                                  selectedEndVerse = null;
                                  _applyQuickReferenceSelector();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${generator.getLocaleString(lang, "verse_num_label")}: ",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Semantics(
                          label: generator.getLocaleString(
                            lang,
                            "verse_num_label",
                          ),
                          child: DropdownButton<int>(
                            value: selectedVerse,
                            menuMaxHeight: 320,
                            items: List<DropdownMenuItem<int>>.generate(
                              maxVerses,
                              (i) => DropdownMenuItem<int>(
                                value: i + 1,
                                child: Text("${i + 1}"),
                              ),
                            ),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  selectedVerse = v;
                                  if (selectedEndVerse != null &&
                                      selectedEndVerse! <= v) {
                                    selectedEndVerse = null;
                                  }
                                  _applyQuickReferenceSelector();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (selectedVerse < maxVerses)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${generator.getLocaleString(lang, "verse_end_label")}: ",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Semantics(
                            label: generator.getLocaleString(
                              lang,
                              "verse_end_label",
                            ),
                            child: DropdownButton<int?>(
                              value: selectedEndVerse,
                              menuMaxHeight: 320,
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(
                                    generator.getLocaleString(
                                      lang,
                                      "verse_end_single",
                                    ),
                                  ),
                                ),
                                ...List<DropdownMenuItem<int?>>.generate(
                                  maxVerses - selectedVerse,
                                  (i) {
                                    final int endNum = selectedVerse + 1 + i;
                                    return DropdownMenuItem<int?>(
                                      value: endNum,
                                      child: Text("$endNum"),
                                    );
                                  },
                                ),
                              ],
                              onChanged: (endV) {
                                setState(() {
                                  selectedEndVerse = endV;
                                  _applyQuickReferenceSelector();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Fetch Verse + Verse of the Day action row right after Book/Chapter/Verse
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: referenceController,
              builder: (context, value, child) {
                return FilledButton.tonalIcon(
                  onPressed:
                      isFetching ||
                          selectedBibleVersion == "-" ||
                          (value.text.trim().isEmpty && selectedBook == null)
                      ? null
                      : _fetchVerse,
                  icon: isFetching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download, size: 18),
                  label: Text(
                    generator.getLocaleString(lang, "fetch_verse_btn"),
                  ),
                );
              },
            ),
            OutlinedButton.icon(
              onPressed:
                  isFetching || selectedBibleVersion == "-"
                      ? null
                      : _fetchVerseOfTheDay,
              icon: const Icon(Icons.wb_sunny_outlined, size: 18),
              label: Text(generator.getLocaleString(lang, "votd_btn")),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: referenceController,
          builder: (context, value, child) {
            return TextField(
              controller: referenceController,
              maxLength: 50,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                labelText: generator.getLocaleString(lang, "reference_label"),
                suffixIcon: value.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: generator.getLocaleString(lang, "clear_btn"),
                        onPressed: referenceController.clear,
                      )
                    : null,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: verseController,
          builder: (context, value, child) {
            return TextField(
              controller: verseController,
              maxLength: 2000,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                labelText: generator.getLocaleString(lang, "verse_label"),
                suffixIcon: value.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: generator.getLocaleString(lang, "clear_btn"),
                        onPressed: verseController.clear,
                      )
                    : null,
              ),
            );
          },
        ),
        _buildStepNavigationRow(lang, 0),
      ],
    );
  }

  Widget _buildBackgroundTab(String lang, bool isGeminiConnected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            Text(
              generator.getLocaleString(lang, "background_label"),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            DropdownButton<String>(
              value: selectedBackground,
              items: backgrounds
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() {
                selectedBackground = v!;
                customImagePath = null;
                isGeminiBackground = false;
              }),
            ),
            FilledButton.tonalIcon(
              onPressed: _selectCustomImage,
              icon: const Icon(Icons.photo_library, size: 18),
              label: Text(generator.getLocaleString(lang, "custom_image_btn")),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: backgrounds.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final String bgName = backgrounds[index];
              final bool isSelected =
                  customImagePath == null && selectedBackground == bgName;
              return GestureDetector(
                onTap: () => setState(() {
                  selectedBackground = bgName;
                  customImagePath = null;
                  isGeminiBackground = false;
                }),
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                    image: DecorationImage(
                      image: AssetImage("assets/backgrounds/$bgName"),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        GeminiBackgroundCard(
          lang: lang,
          generator: generator,
          isConnected: isGeminiConnected,
          selectedStyle: selectedGeminiStyle,
          onStyleChanged: (v) => setState(() => selectedGeminiStyle = v),
          promptController: geminiPromptController,
          verseController: verseController,
          isGenerating: isGeneratingGeminiBg,
          onConnectPressed: _showGeminiAuthDialog,
          onGeneratePressed: _generateGeminiBackground,
        ),
        _buildStepNavigationRow(lang, 1),
      ],
    );
  }

  Widget _buildStyleTab(String lang) {
    final List<Map<String, String>> ratios = [
      {"value": "1:1", "key": "ratio_square"},
      {"value": "3:4", "key": "ratio_portrait"},
      {"value": "9:16", "key": "ratio_story"},
      {"value": "4:3", "key": "ratio_landscape"},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          generator.getLocaleString(lang, "aspect_ratio_label"),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ratios.map((r) {
            final String val = r["value"]!;
            final String label = generator.getLocaleString(lang, r["key"]!);
            return ChoiceChip(
              label: Text(label.isNotEmpty ? label : val),
              selected: aspectRatioStr == val,
              onSelected: (_) => setState(() => aspectRatioStr = val),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          generator.getLocaleString(lang, "font_color_label"),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final entry in _presetColors)
              Builder(
                builder: (context) {
                  final Color preset = entry.key;
                  final bool isSelected =
                      fontColor.toARGB32() == preset.toARGB32();
                  final String colorName = generator.getLocaleString(
                    lang,
                    entry.value,
                  );
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: colorName,
                    child: Tooltip(
                      message: colorName,
                      child: InkResponse(
                        onTap: () => setState(() => fontColor = preset),
                        radius: 24,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: preset,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade400,
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      size: 18,
                                      color: preset.computeLuminance() > 0.5
                                          ? Colors.black
                                          : Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: fontColor,
                foregroundColor: fontColor.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text(
                        generator.getLocaleString(lang, "pick_color_title"),
                      ),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: fontColor,
                          onColorChanged: (c) => setState(() => fontColor = c),
                        ),
                      ),
                      actions: <Widget>[
                        ElevatedButton(
                          child: Text(
                            generator.getLocaleString(lang, "got_it_btn"),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    );
                  },
                );
              },
              icon: const Icon(Icons.color_lens, size: 18),
              label: Text(generator.getLocaleString(lang, "select_color_btn")),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "${generator.getLocaleString(lang, "font_size_label")}: ${fontSize.round()}",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Slider(
          value: fontSize,
          min: 20,
          max: 120,
          divisions: 100,
          label: fontSize.round().toString(),
          onChanged: (v) => setState(() => fontSize = v),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "${generator.getLocaleString(lang, "y_offset_label")}: ${yOffset.round()}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (yOffset.round() != 0)
              TextButton.icon(
                onPressed: () => setState(() => yOffset = 0.0),
                icon: const Icon(Icons.vertical_align_center, size: 16),
                label: Text(
                  generator.getLocaleString(lang, "reset_position_btn"),
                ),
              ),
          ],
        ),
        Slider(
          value: yOffset,
          min: -400,
          max: 400,
          divisions: 800,
          label: yOffset.round().toString(),
          onChanged: (v) => setState(() => yOffset = v),
        ),
        _buildStepNavigationRow(lang, 2),
      ],
    );
  }

  Widget _buildAudioAndTextTab(String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => setState(() => generateAudio = !generateAudio),
                  child: Row(
                    children: [
                      Checkbox(
                        value: generateAudio,
                        onChanged: (v) => setState(() => generateAudio = v!),
                      ),
                      Expanded(
                        child: Text(
                          generator.getLocaleString(lang, "audio_label"),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(generator.getLocaleString(lang, "gender_label")),
                    DropdownButton<String>(
                      value: gender,
                      items: genders.map((v) {
                        final String labelKey = v == "Female"
                            ? "gender_female"
                            : "gender_male";
                        return DropdownMenuItem(
                          value: v,
                          child: Text(
                            generator.getLocaleString(lang, labelKey),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => gender = v!),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: verseController,
                      builder: (context, value, child) {
                        return OutlinedButton.icon(
                          onPressed: value.text.trim().isEmpty
                              ? null
                              : _toggleAudioPreview,
                          icon: Icon(
                            isPlayingAudioPreview
                                ? Icons.stop
                                : Icons.volume_up,
                            size: 18,
                          ),
                          label: Text(
                            generator.getLocaleString(
                              lang,
                              isPlayingAudioPreview
                                  ? "stop_audio_btn"
                                  : "preview_audio_btn",
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (altText.isEmpty && caption.isEmpty) ...[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  Icon(
                    Icons.accessibility_new,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      generator.getLocaleString(lang, "text_empty_state"),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (altText.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            generator.getLocaleString(lang, "alt_text_label"),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          SelectableText(altText),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => _copyToClipboard(altText, fieldKey: "alt"),
            icon: Icon(
              _copiedField == "alt" ? Icons.check : Icons.copy,
              size: 16,
              color: _copiedField == "alt" ? Colors.green : null,
            ),
            label: Text(generator.getLocaleString(lang, "copy_alt_text_btn")),
          ),
        ],
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            generator.getLocaleString(lang, "caption_label"),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          SelectableText(caption),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => _copyToClipboard(caption, fieldKey: "caption"),
            icon: Icon(
              _copiedField == "caption" ? Icons.check : Icons.copy,
              size: 16,
              color: _copiedField == "caption" ? Colors.green : null,
            ),
            label: Text(generator.getLocaleString(lang, "copy_caption_btn")),
          ),
        ],
        _buildStepNavigationRow(lang, 3),
      ],
    );
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _stepTabKeys.length || index == _selectedTabIndex) {
      return;
    }
    setState(() => _selectedTabIndex = index);
    if (_workspaceScrollController.hasClients) {
      if (MediaQuery.of(context).disableAnimations) {
        _workspaceScrollController.jumpTo(0);
      } else {
        _workspaceScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Widget _buildStepProgressHeader(String lang) {
    final String stepName = generator.getLocaleString(
      lang,
      _stepTabKeys[_selectedTabIndex],
    );
    final String label = generator
        .getLocaleString(lang, "step_progress_label")
        .replaceAll("{current}", "${_selectedTabIndex + 1}")
        .replaceAll("{total}", "${_stepTabKeys.length}")
        .replaceAll("{step}", stepName);

    return Semantics(
      liveRegion: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: (_selectedTabIndex + 1) / _stepTabKeys.length,
            minHeight: 4,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withAlpha(60),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepNavigationRow(String lang, int stepIndex) {
    final bool hasBack = stepIndex > 0;
    final bool hasNext = stepIndex < _stepTabKeys.length - 1;
    final String nextStepName = hasNext
        ? generator.getLocaleString(lang, _stepTabKeys[stepIndex + 1])
        : "";
    final String nextLabel = generator
        .getLocaleString(lang, "step_next_label")
        .replaceAll("{step}", nextStepName);

    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 4.0),
      child: Row(
        children: [
          if (hasBack)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
              ),
              onPressed: () => _selectTab(stepIndex - 1),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(generator.getLocaleString(lang, "step_back_btn")),
            ),
          if (hasBack && hasNext) const SizedBox(width: 12),
          if (hasNext)
            Expanded(
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () => _selectTab(stepIndex + 1),
                icon: const Icon(Icons.arrow_forward, size: 18),
                iconAlignment: IconAlignment.end,
                label: Text(nextLabel),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(String lang) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      Icon(
                        isError
                            ? Icons.error
                            : (isSuccess ? Icons.check_circle : Icons.info),
                        size: 18,
                        color: isError
                            ? Theme.of(context).colorScheme.error
                            : (isSuccess
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          statusMessage,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isError
                                ? Theme.of(context).colorScheme.error
                                : (isSuccess
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _previewListenable,
                builder: (context, child) {
                  return FilledButton.icon(
                    onPressed:
                        isGenerating ||
                            verseController.text.trim().isEmpty ||
                            referenceController.text.trim().isEmpty
                        ? null
                        : _generateContent,
                    icon: isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share),
                    label: Text(
                      generator.getLocaleString(lang, "generate_btn"),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String lang = getLangKey();
    final bool isGeminiConnected =
        geminiApiKey != null && geminiApiKey!.isNotEmpty;

    final Widget previewWidget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.contain,
            child: VersePreviewCard(
              repaintKey: _globalKey,
              aspectRatioStr: aspectRatioStr,
              customImagePath: customImagePath,
              selectedBackground: selectedBackground,
              previewListenable: _previewListenable,
              verseController: verseController,
              referenceController: referenceController,
              fontColor: fontColor,
              fontSize: fontSize,
              yOffset: yOffset,
              onYOffsetChanged: (updated) => setState(() => yOffset = updated),
              lang: lang,
              generator: generator,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          generator.getLocaleString(lang, "drag_hint"),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );

    final Widget tabNavigation = NavigationBar(
      height: 60,
      selectedIndex: _selectedTabIndex,
      onDestinationSelected: _selectTab,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.menu_book_outlined),
          selectedIcon: const Icon(Icons.menu_book),
          label: generator.getLocaleString(lang, "tab_verse"),
        ),
        NavigationDestination(
          icon: const Icon(Icons.wallpaper_outlined),
          selectedIcon: const Icon(Icons.wallpaper),
          label: generator.getLocaleString(lang, "tab_background"),
        ),
        NavigationDestination(
          icon: const Icon(Icons.text_fields_outlined),
          selectedIcon: const Icon(Icons.text_fields),
          label: generator.getLocaleString(lang, "tab_style"),
        ),
        NavigationDestination(
          icon: const Icon(Icons.record_voice_over_outlined),
          selectedIcon: const Icon(Icons.record_voice_over),
          label: generator.getLocaleString(lang, "tab_audio"),
        ),
      ],
    );

    final Widget tabbedWorkspace = IndexedStack(
      index: _selectedTabIndex,
      children: [
        _buildVerseTab(lang),
        _buildBackgroundTab(lang, isGeminiConnected),
        _buildStyleTab(lang),
        _buildAudioAndTextTab(lang),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(generator.getLocaleString(lang, "title")),
        actions: [
          IconButton(
            tooltip: generator.getLocaleString(
              lang,
              isGeminiConnected ? "gemini_connected_btn" : "gemini_connect_btn",
            ),
            icon: Icon(
              isGeminiConnected ? Icons.auto_awesome : Icons.key_outlined,
              color: isGeminiConnected ? Colors.amber : null,
            ),
            onPressed: _showGeminiAuthDialog,
          ),
          DropdownButton<String>(
            value: currentLang,
            onChanged: (String? newValue) {
              setState(() {
                currentLang = newValue!;
                bibleLang = getLangKey().substring(0, 2);
                _syncDefaultBookForLanguage();
                _loadBibleVersions();
              });
            },
            items: languages.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(lang),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      tabNavigation,
                      _buildStepProgressHeader(lang),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _workspaceScrollController,
                          padding: const EdgeInsets.all(16.0),
                          child: tabbedWorkspace,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: previewWidget,
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                // Pinned Live Preview at the Top
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxHeight: (constraints.maxHeight * 0.36).clamp(
                      180.0,
                      290.0,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 6.0,
                  ),
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withAlpha(80),
                  child: Center(child: previewWidget),
                ),
                tabNavigation,
                _buildStepProgressHeader(lang),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _workspaceScrollController,
                    padding: const EdgeInsets.all(14.0),
                    child: tabbedWorkspace,
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
