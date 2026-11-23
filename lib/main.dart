import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'book_mapping.dart';
import 'generator.dart';
import 'getbible_api.dart';
import 'services/color_accessibility.dart';
import 'services/contrast_sampler.dart';
import 'services/gemini_handoff_service.dart';
import 'services/gemini_nano_service.dart';
import 'services/image_validation.dart';
import 'services/media_export_service.dart';
import 'services/temp_file_cleanup.dart';
import 'services/tts_service.dart';
import 'services/voice_verse_service.dart';
import 'widgets/verse_preview_card.dart';
import 'widgets/vision_simulation.dart';

Locale resolveLocaleForAppLanguage(String languageName) {
  if (languageName.startsWith("English")) return const Locale('en');
  if (languageName.startsWith("Español")) return const Locale('es');
  return const Locale('pt', 'BR');
}

String resolveAppLanguageForLocale(Locale locale) {
  switch (locale.languageCode.toLowerCase()) {
    case 'pt':
      return "Português (Brasil)";
    case 'es':
      return "Español (España)";
    case 'en':
    default:
      return "English (US/UK)";
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  final Generator? generator;
  final TtsService? ttsService;
  final MediaExportService? mediaExportService;
  final GeminiNanoService? geminiNanoService;
  final GeminiHandoffService? geminiHandoffService;
  final VoiceVerseService? voiceVerseService;
  final ContrastSampler? contrastSampler;
  final Future<List<BibleSearchResult>> Function(
    String query,
    String versionId,
    String lang,
  )? verseSearchOverride;

  const MyApp({
    super.key,
    this.generator,
    this.ttsService,
    this.mediaExportService,
    this.geminiNanoService,
    this.geminiHandoffService,
    this.voiceVerseService,
    this.contrastSampler,
    this.verseSearchOverride,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const Color _editorialSeed = Color(0xFF284B8C);
  bool _highContrastUi = false;
  Locale? _appLocale;

  ThemeData _buildTheme(
    Brightness brightness, {
    bool forceHighContrast = false,
  }) {
    final bool isDark = brightness == Brightness.dark;
    final bool useHighContrast = _highContrastUi || forceHighContrast;
    final ColorScheme colorScheme = useHighContrast
        ? (isDark
              ? const ColorScheme.highContrastDark()
              : const ColorScheme.highContrastLight())
        : ColorScheme.fromSeed(
            seedColor: _editorialSeed,
            brightness: brightness,
          );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      focusColor: colorScheme.primary.withValues(
        alpha: useHighContrast ? 0.32 : 0.18,
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: useHighContrast
                ? colorScheme.onSurface
                : colorScheme.outlineVariant,
            width: useHighContrast ? 1.5 : 1.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inclusive Bible Generator',
      debugShowCheckedModeBanner: false,
      locale: _appLocale,
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
        Locale('pt', 'BR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      highContrastTheme: _buildTheme(Brightness.light, forceHighContrast: true),
      highContrastDarkTheme: _buildTheme(
        Brightness.dark,
        forceHighContrast: true,
      ),
      themeMode: ThemeMode.system,
      home: MyHomePage(
        generator: widget.generator,
        ttsService: widget.ttsService,
        mediaExportService: widget.mediaExportService,
        geminiNanoService: widget.geminiNanoService,
        geminiHandoffService: widget.geminiHandoffService,
        voiceVerseService: widget.voiceVerseService,
        contrastSampler: widget.contrastSampler,
        verseSearchOverride: widget.verseSearchOverride,
        highContrastUi: _highContrastUi,
        onHighContrastChanged: (bool value) {
          if (_highContrastUi != value) {
            setState(() => _highContrastUi = value);
          }
        },
        onLocaleChanged: (Locale locale) {
          if (_appLocale != locale) {
            setState(() => _appLocale = locale);
          }
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final Generator? generator;
  final TtsService? ttsService;
  final MediaExportService? mediaExportService;
  final GeminiNanoService? geminiNanoService;
  final GeminiHandoffService? geminiHandoffService;
  final VoiceVerseService? voiceVerseService;
  final ContrastSampler? contrastSampler;
  final Future<List<BibleSearchResult>> Function(
    String query,
    String versionId,
    String lang,
  )? verseSearchOverride;
  final bool highContrastUi;
  final ValueChanged<bool>? onHighContrastChanged;
  final ValueChanged<Locale>? onLocaleChanged;

  const MyHomePage({
    super.key,
    this.generator,
    this.ttsService,
    this.mediaExportService,
    this.geminiNanoService,
    this.geminiHandoffService,
    this.voiceVerseService,
    this.contrastSampler,
    this.verseSearchOverride,
    this.highContrastUi = false,
    this.onHighContrastChanged,
    this.onLocaleChanged,
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
    MapEntry(Color(0xFF0D2B52), "color_deep_navy"),
    MapEntry(Colors.black, "color_black"),
  ];

  static const List<MapEntry<String, VerseTextStyleOptions>> _stylePresets = [
    MapEntry(
      "preset_editorial",
      VerseTextStyleOptions(
        fontFamily: VerseFontFamily.playfairDisplay,
        isBold: true,
        isItalic: false,
        shadow: VerseTextShadow.soft,
        textAlign: TextAlign.center,
        backdrop: VerseTextBackdrop.none,
        accent: VerseCardAccent.divider,
        lineHeight: 1.30,
      ),
    ),
    MapEntry(
      "preset_minimal",
      VerseTextStyleOptions(
        fontFamily: VerseFontFamily.montserrat,
        isBold: true,
        isItalic: false,
        shadow: VerseTextShadow.soft,
        textAlign: TextAlign.left,
        backdrop: VerseTextBackdrop.none,
        lineHeight: 1.25,
      ),
    ),
    MapEntry(
      "preset_devotional",
      VerseTextStyleOptions(
        fontFamily: VerseFontFamily.lora,
        isBold: false,
        isItalic: true,
        shadow: VerseTextShadow.none,
        textAlign: TextAlign.center,
        backdrop: VerseTextBackdrop.frosted,
        lineHeight: 1.40,
      ),
    ),
    MapEntry(
      "preset_wcag",
      VerseTextStyleOptions(
        fontFamily: VerseFontFamily.sans,
        isBold: true,
        isItalic: false,
        shadow: VerseTextShadow.none,
        textAlign: TextAlign.center,
        backdrop: VerseTextBackdrop.solid,
        lineHeight: 1.35,
      ),
    ),
    MapEntry(
      "preset_dyslexia",
      VerseTextStyleOptions(
        fontFamily: VerseFontFamily.sans,
        isBold: false,
        isItalic: false,
        shadow: VerseTextShadow.none,
        textAlign: TextAlign.left,
        backdrop: VerseTextBackdrop.solid,
        lineHeight: 1.50,
        letterSpacing: 0.40,
      ),
    ),
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
  late final TtsService ttsService;
  late final MediaExportService mediaExportService;
  late final GeminiNanoService geminiNanoService;
  late final GeminiHandoffService geminiHandoffService;
  late final VoiceVerseService voiceVerseService;
  late final ContrastSampler contrastSampler;
  final GlobalKey _globalKey = GlobalKey();

  GeminiNanoAvailability _geminiNanoAvailability =
      GeminiNanoAvailability.unavailable;
  bool _geminiNanoEnabled = false;
  bool _geminiHandoffEnabled = false;
  bool _highContrastUiEnabled = false;
  bool _colorBlindUiEnabled = false;
  bool _voiceInputAvailable = false;
  bool _isListeningVoice = false;
  bool _isDescribingImage = false;
  String? _onDeviceImageDescription;
  final TextEditingController _imageDescriptionController =
      TextEditingController();
  final FocusNode _imageDescriptionFocusNode = FocusNode();
  final TextEditingController _verseSearchController = TextEditingController();
  BackgroundLuminanceProfile? _sampledBgProfile;
  int _sampleSeq = 0;
  (int, int)? _spokenWordRange;

  int _selectedTabIndex = 0;

  String currentLang = "Português (Brasil)";
  final List<String> languages = const [
    "Português (Brasil)",
    "English (US/UK)",
    "Español (España)",
  ];

  static String _shortLanguageCode(String languageName) {
    if (languageName.startsWith("English")) return "EN-US";
    if (languageName.startsWith("Español")) return "ES-ES";
    return "PT-BR";
  }

  static String _shortBibleLangCode(String code) {
    if (code == "en") return "EN-US";
    if (code == "es") return "ES-ES";
    return "PT-BR";
  }

  static String _fullBibleLangLabel(String code) {
    if (code == "en") return "English";
    if (code == "es") return "Español";
    return "Português";
  }

  static const List<String> _bibleLangCodes = ["pt", "en", "es"];

  String bibleLang = "pt";
  String youVersionApiKey = GetBibleAPI.defaultYouVersionApiKey;

  List<String> bibleVersions = ["-"];
  String selectedBibleVersion = "-";
  Map<String, String> bibleVersionsMap = {};
  Map<String, String> _preferredBibleVersions = {};
  int _verseFetchSeq = 0;

  // ⚡ Bolt: Memoize dropdown menu items so unrelated setState() calls don't
  // allocate ~460+ DropdownMenuItem/Text widgets on every rebuild.
  String? _cachedBooksLang;
  List<DropdownMenuItem<String>> _cachedBookItems = const [];
  int _cachedMaxChapters = -1;
  List<DropdownMenuItem<int>> _cachedChapterItems = const [];
  int _cachedMaxVerses = -1;
  List<DropdownMenuItem<int>> _cachedVerseItems = const [];
  String? _cachedEndVerseKey;
  List<DropdownMenuItem<int?>> _cachedEndVerseItems = const [];

  List<DropdownMenuItem<String>> _getBookDropdownItems(
    String langKey,
    List<String> canonicalBooks,
  ) {
    if (_cachedBooksLang != langKey ||
        _cachedBookItems.length != canonicalBooks.length) {
      _cachedBooksLang = langKey;
      _cachedBookItems = canonicalBooks
          .map(
            (b) => DropdownMenuItem<String>(
              value: b,
              child: Text(b, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false);
    }
    return _cachedBookItems;
  }

  List<DropdownMenuItem<int>> _getChapterDropdownItems(int maxChapters) {
    if (_cachedMaxChapters != maxChapters) {
      _cachedMaxChapters = maxChapters;
      _cachedChapterItems = List<DropdownMenuItem<int>>.generate(
        maxChapters,
        (i) => DropdownMenuItem<int>(value: i + 1, child: Text("${i + 1}")),
        growable: false,
      );
    }
    return _cachedChapterItems;
  }

  List<DropdownMenuItem<int>> _getVerseDropdownItems(int maxVerses) {
    if (_cachedMaxVerses != maxVerses) {
      _cachedMaxVerses = maxVerses;
      _cachedVerseItems = List<DropdownMenuItem<int>>.generate(
        maxVerses,
        (i) => DropdownMenuItem<int>(value: i + 1, child: Text("${i + 1}")),
        growable: false,
      );
    }
    return _cachedVerseItems;
  }

  List<DropdownMenuItem<int?>> _getEndVerseDropdownItems(
    String uiLang,
    int startVerse,
    int maxVerses,
  ) {
    final String key = "$uiLang:$startVerse:$maxVerses";
    if (_cachedEndVerseKey != key) {
      _cachedEndVerseKey = key;
      _cachedEndVerseItems = [
        DropdownMenuItem<int?>(
          value: null,
          child: Text(generator.getLocaleString(uiLang, "verse_end_single")),
        ),
        for (int endNum = startVerse + 1; endNum <= maxVerses; endNum++)
          DropdownMenuItem<int?>(value: endNum, child: Text("$endNum")),
      ];
    }
    return _cachedEndVerseItems;
  }

  String? selectedBook;
  int selectedChapter = 119;
  int selectedVerse = 105;
  int? selectedEndVerse;
  final TextEditingController referenceController = TextEditingController();
  final TextEditingController verseController = TextEditingController();

  static final RegExp _fileExtensionRegExp = RegExp(r'\.[^.]+$');

  String selectedBackground = "default.png";
  List<String> backgrounds = ["default.png"];
  Map<String, String> _backgroundLabels = const {};
  List<DropdownMenuItem<String>> _cachedBackgroundItems = const [];
  String? customImagePath;
  // ⚡ Bolt: Use ValueNotifiers for continuous slider/drag values to avoid full-tree rebuilds
  final ValueNotifier<double> _backgroundDimNotifier = ValueNotifier<double>(0.15);
  double get backgroundDim => _backgroundDimNotifier.value;
  set backgroundDim(double v) => _backgroundDimNotifier.value = v;

  final ValueNotifier<Color> _fontColorNotifier = ValueNotifier<Color>(
    Colors.white,
  );
  Color get fontColor => _fontColorNotifier.value;
  set fontColor(Color c) => _fontColorNotifier.value = c;
  final ValueNotifier<double> _fontSizeNotifier = ValueNotifier<double>(22.0);
  double get fontSize => _fontSizeNotifier.value;
  set fontSize(double v) => _fontSizeNotifier.value = v;
  String aspectRatioStr = "1:1";
  final ValueNotifier<double> _yOffsetNotifier = ValueNotifier<double>(0.0);
  double get yOffset => _yOffsetNotifier.value;
  set yOffset(double v) => _yOffsetNotifier.value = v;
  final ValueNotifier<VerseTextStyleOptions> _textStyleNotifier =
      ValueNotifier<VerseTextStyleOptions>(const VerseTextStyleOptions());

  static const String accessibilityStatementUrl =
      'https://ronalds1979.github.io/inclusive-bible-generator-android/accessibility-statement.html';
  static const String privacyPolicyUrl =
      'https://ronalds1979.github.io/inclusive-bible-generator-android/privacy-policy.html';

  bool generateAudio = false;
  bool isPlayingAudioPreview = false;
  double _ttsSpeedMultiplier = 1.0;
  static const List<double> _ttsSpeedOptions = [0.75, 1.0, 1.25, 1.5];
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
    if (isError || isSuccess) {
      HapticFeedback.mediumImpact();
    }
  }

  bool isLoading = true;
  bool isFetching = false;
  bool isGenerating = false;
  late final Listenable _previewListenable;
  late final Listenable _contrastListenable;
  late final Listenable _scorecardListenable;

  @override
  void initState() {
    super.initState();
    final Locale deviceLocale =
        WidgetsBinding.instance.platformDispatcher.locale;
    currentLang = resolveAppLanguageForLocale(deviceLocale);
    bibleLang = getLangKey().substring(0, 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onLocaleChanged?.call(resolveLocaleForAppLanguage(currentLang));
      }
    });
    generator = widget.generator ?? Generator();
    ttsService = widget.ttsService ?? TtsService();
    mediaExportService = widget.mediaExportService ?? MediaExportService();
    geminiNanoService = widget.geminiNanoService ?? const GeminiNanoService();
    geminiHandoffService =
        widget.geminiHandoffService ?? const GeminiHandoffService();
    voiceVerseService = widget.voiceVerseService ?? const VoiceVerseService();
    contrastSampler = widget.contrastSampler ?? const ContrastSampler();
    _previewListenable = Listenable.merge([
      referenceController,
      verseController,
      _imageDescriptionController,
    ]);
    _contrastListenable = Listenable.merge([
      _backgroundDimNotifier,
      _fontColorNotifier,
      _textStyleNotifier,
      _yOffsetNotifier,
    ]);
    // ⚡ Bolt: Cache scorecard Listenable.merge once instead of reallocating per build()
    _scorecardListenable = Listenable.merge([
      _previewListenable,
      _contrastListenable,
      _fontSizeNotifier,
    ]);
    _initApp();
  }

  @override
  void dispose() {
    _copyFeedbackTimer?.cancel();
    _workspaceScrollController.dispose();
    _backgroundDimNotifier.dispose();
    _fontColorNotifier.dispose();
    _fontSizeNotifier.dispose();
    _yOffsetNotifier.dispose();
    _textStyleNotifier.dispose();
    _imageDescriptionController.dispose();
    _imageDescriptionFocusNode.dispose();
    _verseSearchController.dispose();
    referenceController.dispose();
    verseController.dispose();
    ttsService.stop();
    super.dispose();
  }

  Future<void> _cleanupStartupTransientFiles() async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      await Future.wait([
        pruneTransientFiles(tempDir, prefix: 'verse_', suffix: '.png'),
        pruneTransientFiles(tempDir, prefix: 'verse_video_', suffix: '.mp4'),
        pruneTransientFiles(tempDir, prefix: 'gemini_bg_', suffix: '.png'),
        pruneTransientFiles(tempDir, prefix: 'stock_bg_', suffix: '.jpg'),
        pruneTransientFiles(tempDir, prefix: 'verse_audio_', suffix: '.wav'),
      ]);
    } catch (_) {}
  }

  Future<void> _initApp() async {
    unawaited(_cleanupStartupTransientFiles());
    // ⚡ Bolt: Parallelize independent startup I/O (locales, secure storage keys, asset manifest, device capability check)
    final results = await Future.wait<dynamic>([
      generator.loadLocales(),
      GetBibleAPI.loadYouVersionApiKey(),
      _loadBackgrounds(),
      _loadPreferredBibleVersions(),
      geminiNanoService.checkAvailability(),
      _loadAdvancedPreferences(),
      _loadTypographyStyle(),
      voiceVerseService.isAvailable(),
    ]);
    final String providedYouVersionKey =
        GetBibleAPI.defaultYouVersionApiKey.trim();
    youVersionApiKey = providedYouVersionKey.isNotEmpty
        ? providedYouVersionKey
        : ((results[1] as String?) ?? '');
    _geminiNanoAvailability = results[4] as GeminiNanoAvailability;
    _voiceInputAvailable = results[7] as bool;
    if (!_geminiNanoAvailability.isCompatible) {
      _geminiNanoEnabled = false;
    }
    unawaited(_sampleCurrentBackgroundLuminance());
    _syncDefaultBookForLanguage();
    // ⚡ Bolt: Populate built-in Bible versions synchronously so cold start isn't blocked by network I/O
    final builtIn = GetBibleAPI.getBuiltInVersions(bibleLang);
    if (builtIn.isNotEmpty) {
      bibleVersionsMap = {for (var v in builtIn) v["name"]!: v["id"]!};
      bibleVersions = bibleVersionsMap.keys.toList();
      selectedBibleVersion = _resolvePreferredVersionForLang(
        bibleLang,
        bibleVersions,
      );
    }
    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
    // Merge YouVersion versions asynchronously in the background
    _loadBibleVersions();
    // Pre-populate with Verse of the Day so users have ready-to-share content on launch
    _fetchVerseOfTheDay(onlyIfEmpty: true);
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

  void _onQuickReferenceChanged() {
    _applyQuickReferenceSelector();
    _fetchVerse();
  }

  bool _syncSelectorsFromReference(String reference) {
    final Map<String, String?> parsed = GetBibleAPI.parseReference(
      reference,
      lang: bibleLang,
    );
    final int? bookNr = int.tryParse(parsed["book_nr"] ?? "");
    if (bookNr == null) return false;
    final String? canonicalBook = getBookNameByNumber(bookNr, bibleLang);
    if (canonicalBook == null) return false;

    selectedBook = canonicalBook;
    selectedChapter = int.tryParse(parsed["chapter"] ?? "1") ?? 1;
    selectedVerse = int.tryParse(parsed["start_verse"] ?? "1") ?? 1;
    final int? parsedEnd = int.tryParse(parsed["end_verse"] ?? "");
    selectedEndVerse =
        (parsedEnd != null && parsedEnd > selectedVerse) ? parsedEnd : null;
    _clampChapterAndVerse();
    return true;
  }

  void _rebuildBackgroundCaches() {
    final Map<String, String> labels = {};
    final List<DropdownMenuItem<String>> items = [];
    for (final bgName in backgrounds) {
      final String label = _formatBackgroundName(bgName);
      labels[bgName] = label;
      items.add(DropdownMenuItem<String>(value: bgName, child: Text(label)));
    }
    _backgroundLabels = labels;
    _cachedBackgroundItems = List<DropdownMenuItem<String>>.unmodifiable(items);
  }

  String _getBackgroundLabel(String bgName) {
    return _backgroundLabels[bgName] ?? _formatBackgroundName(bgName);
  }

  List<DropdownMenuItem<String>> _getBackgroundDropdownItems() {
    if (_cachedBackgroundItems.length != backgrounds.length) {
      _rebuildBackgroundCaches();
    }
    return _cachedBackgroundItems;
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
    _rebuildBackgroundCaches();
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

  Future<void> _loadPreferredBibleVersions() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/preferred_bible_versions.json');
      if (await file.exists()) {
        final int fileLen = await file.length();
        if (fileLen <= 0 || fileLen > 64 * 1024) return;
        final dynamic decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          const Set<String> allowedLangs = {'pt', 'en', 'es'};
          final Map<String, String> sanitized = {};
          for (final entry in decoded.entries) {
            final String key = entry.key.toString();
            final String value = entry.value.toString();
            if (allowedLangs.contains(key) && value.length <= 120) {
              sanitized[key] = value;
            }
          }
          _preferredBibleVersions = sanitized;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error loading preferred Bible versions: $e");
      }
    }
  }

  Future<void> _savePreferredBibleVersion(
    String langCode,
    String versionName,
  ) async {
    _preferredBibleVersions[langCode] = versionName;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/preferred_bible_versions.json');
      await file.writeAsString(jsonEncode(_preferredBibleVersions));
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error saving preferred Bible version: $e");
      }
    }
  }

  Future<void> _loadAdvancedPreferences() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/advanced_features.json');
      if (await file.exists()) {
        final int fileLen = await file.length();
        if (fileLen <= 0 || fileLen > 16 * 1024) return;
        final dynamic decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          _geminiNanoEnabled = decoded['gemini_nano_enabled'] == true;
          _geminiHandoffEnabled = decoded['gemini_handoff_enabled'] == true;
          _highContrastUiEnabled = decoded['high_contrast_ui'] == true;
          _colorBlindUiEnabled = decoded['color_blind_ui'] == true;
          if (_highContrastUiEnabled) {
            widget.onHighContrastChanged?.call(true);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error loading advanced feature preferences: $e");
      }
    }
  }

  Future<void> _saveAdvancedPreferences() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/advanced_features.json');
      await file.writeAsString(
        jsonEncode({
          'gemini_nano_enabled': _geminiNanoEnabled,
          'gemini_handoff_enabled': _geminiHandoffEnabled,
          'high_contrast_ui': _highContrastUiEnabled,
          'color_blind_ui': _colorBlindUiEnabled,
        }),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error saving advanced feature preferences: $e");
      }
    }
  }

  void _updateTextStyle(VerseTextStyleOptions next) {
    _textStyleNotifier.value = next;
    unawaited(_saveTypographyStyle(next));
  }

  Future<void> _loadTypographyStyle() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/typography_style.json');
      if (await file.exists()) {
        final int fileLen = await file.length();
        if (fileLen <= 0 || fileLen > 16 * 1024) return;
        final dynamic decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          _textStyleNotifier.value = VerseTextStyleOptions.fromJson(decoded);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error loading typography style preferences: $e");
      }
    }
  }

  Future<void> _saveTypographyStyle(VerseTextStyleOptions style) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/typography_style.json');
      await file.writeAsString(jsonEncode(style.toJson()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error saving typography style preferences: $e");
      }
    }
  }

  String _resolvePreferredVersionForLang(
    String langCode,
    List<String> availableVersions,
  ) {
    final String? preferred = _preferredBibleVersions[langCode];
    if (preferred != null && availableVersions.contains(preferred)) {
      return preferred;
    }
    return availableVersions.first;
  }

  void _switchBibleLanguage(String newBibleLang) {
    setState(() {
      bibleLang = newBibleLang;
      _syncDefaultBookForLanguage();
      final builtIn = GetBibleAPI.getBuiltInVersions(bibleLang);
      if (builtIn.isNotEmpty) {
        bibleVersionsMap = {for (var v in builtIn) v["name"]!: v["id"]!};
        bibleVersions = bibleVersionsMap.keys.toList();
        selectedBibleVersion = _resolvePreferredVersionForLang(
          bibleLang,
          bibleVersions,
        );
      }
    });
    _loadBibleVersions(reloadVotd: true);
  }

  Future<void> _loadBibleVersions({bool reloadVotd = false}) async {
    final String requestedLang = bibleLang;
    final bool hasYouVersionKey =
        youVersionApiKey.trim().isNotEmpty ||
        GetBibleAPI.defaultYouVersionApiKey.trim().isNotEmpty;

    // ⚡ Bolt: Avoid redundant "Loading..." -> "" setState churn when only synchronous
    // built-in versions are used (no YouVersion API key configured).
    if (!hasYouVersionKey) {
      if (reloadVotd) {
        await _fetchVerseOfTheDay();
      }
      return;
    }

    final String uiLang = getLangKey();
    setState(() {
      _updateStatus(generator.getLocaleString(uiLang, "loading_versions_msg"));
    });

    final versions = await GetBibleAPI.getVersions(
      lang: requestedLang,
      youVersionApiKey: youVersionApiKey,
    );
    if (!mounted || requestedLang != bibleLang) return;
    if (versions.isNotEmpty) {
      bibleVersionsMap = {for (var v in versions) v["name"]!: v["id"]!};
      bibleVersions = bibleVersionsMap.keys.toList();
      selectedBibleVersion = _resolvePreferredVersionForLang(
        requestedLang,
        bibleVersions,
      );
      setState(() {
        _updateStatus("");
      });
      if (reloadVotd) {
        await _fetchVerseOfTheDay();
      }
    } else {
      setState(() {
        bibleVersions = ["-"];
        selectedBibleVersion = "-";
        _updateStatus(
          generator.getLocaleString(getLangKey(), "error_loading_versions_msg"),
          forceError: true,
        );
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
        _updateStatus(
          generator.getLocaleString(getLangKey(), "missing_version_or_ref_msg"),
        );
      });
      return;
    }

    final String? bibleId = bibleVersionsMap[selectedBibleVersion];
    if (bibleId == null) return;

    final int seq = ++_verseFetchSeq;
    setState(() {
      _syncSelectorsFromReference(reference);
      isFetching = true;
      _updateStatus(
        generator.getLocaleString(getLangKey(), "fetching_verse_msg"),
      );
    });

    final String? content = await GetBibleAPI.getPassage(
      bibleId,
      reference,
      lang: bibleLang,
      youVersionApiKey: youVersionApiKey,
    );
    if (!mounted || seq != _verseFetchSeq) return;
    if (content != null) {
      final Map<String, String> previewTexts = await generator.generateTexts(
        getLangKey(),
        content,
        reference,
      );
      if (!mounted || seq != _verseFetchSeq) return;
      setState(() {
        isFetching = false;
        verseController.text = content;
        altText = previewTexts["altText"]!;
        caption = previewTexts["caption"]!;
        _updateStatus(
          generator.getLocaleString(getLangKey(), "verse_fetched_success_msg"),
          forceSuccess: true,
        );
      });
    } else {
      setState(() {
        isFetching = false;
        _updateStatus(
          generator.getLocaleString(getLangKey(), "error_fetching_verse_msg"),
          forceError: true,
        );
      });
    }
  }

  Future<void> _fetchVerseOfTheDay({bool onlyIfEmpty = false}) async {
    if (onlyIfEmpty && verseController.text.trim().isNotEmpty) return;
    final String? bibleId = bibleVersionsMap[selectedBibleVersion];
    if (bibleId == null || selectedBibleVersion == "-") return;

    final int seq = ++_verseFetchSeq;
    setState(() {
      isFetching = true;
      _updateStatus(
        generator.getLocaleString(getLangKey(), "fetching_votd_msg"),
      );
    });

    final Map<String, String>? votd = await GetBibleAPI.getVerseOfTheDay(
      lang: bibleLang,
      bibleId: bibleId,
      youVersionApiKey: youVersionApiKey,
    );
    if (!mounted || seq != _verseFetchSeq) return;
    if (onlyIfEmpty && verseController.text.trim().isNotEmpty) {
      setState(() => isFetching = false);
      return;
    }

    if (votd != null) {
      final String content = votd["text"]!;
      final String reference = votd["reference"]!;
      final Map<String, String> previewTexts = await generator.generateTexts(
        getLangKey(),
        content,
        reference,
      );
      if (!mounted || seq != _verseFetchSeq) return;
      if (onlyIfEmpty && verseController.text.trim().isNotEmpty) {
        setState(() => isFetching = false);
        return;
      }
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
        _updateStatus(
          generator.getLocaleString(getLangKey(), "votd_loaded_msg"),
          forceSuccess: true,
        );
      });
    } else {
      setState(() {
        isFetching = false;
        _updateStatus(
          generator.getLocaleString(getLangKey(), "error_loading_votd_msg"),
          forceError: true,
        );
      });
    }
  }

  Future<void> _selectCustomImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // 🛡️ Sentinel: Validate file size (1B..20MB) and raster image magic bytes before UI rendering
      final File selectedFile = File(image.path);
      final int fileSize = await selectedFile.length();
      final List<int> headerBytes = await selectedFile
          .openRead(0, 12)
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
      if (fileSize <= 0 ||
          fileSize > 20 * 1024 * 1024 ||
          !isValidRasterImageBytes(Uint8List.fromList(headerBytes))) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              generator.getLocaleString(
                getLangKey(),
                "image_size_limit_error",
              ),
            ),
          ),
        );
        return;
      }

      setState(() {
        customImagePath = image.path;
        _onDeviceImageDescription = null;
        _imageDescriptionController.clear();
      });
      unawaited(_sampleCurrentBackgroundLuminance());
    }
  }

  Future<void> _showVerseSearchDialog() async {
    final String lang = getLangKey();
    final String versionId = bibleVersionsMap[selectedBibleVersion] ?? "web";
    _verseSearchController.clear();
    List<BibleSearchResult> results = const [];
    bool searching = false;
    bool hasSearched = false;

    const List<String> themeKeys = [
      "verse_search_theme_peace",
      "verse_search_theme_hope",
      "verse_search_theme_love",
      "verse_search_theme_strength",
      "verse_search_theme_faith",
    ];

    final BibleSearchResult? picked = await showDialog<BibleSearchResult>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            Future<void> runSearch(String rawQuery) async {
              final String q = rawQuery.trim();
              if (q.length < 2 || searching) return;
              setDialogState(() {
                searching = true;
                hasSearched = true;
              });
              final List<BibleSearchResult> fetched =
                  widget.verseSearchOverride != null
                  ? await widget.verseSearchOverride!(q, versionId, bibleLang)
                  : await GetBibleAPI.searchVerses(
                      query: q,
                      versionId: versionId,
                      lang: bibleLang,
                    );
              if (!dialogContext.mounted) return;
              setDialogState(() {
                results = fetched;
                searching = false;
              });
            }

            return AlertDialog(
              title: Text(
                generator.getLocaleString(lang, "verse_search_title"),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _verseSearchController,
                        builder: (context, value, _) {
                          final bool canSearch =
                              !searching && value.text.trim().length >= 2;
                          return Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _verseSearchController,
                                  // 🛡️ Sentinel: Cap search query length at the UI boundary (matches GetBibleAPI.searchVerses)
                                  maxLength: 160,
                                  autofocus: true,
                                  textInputAction: TextInputAction.search,
                                  decoration: InputDecoration(
                                    counterText: '',
                                    labelText: generator.getLocaleString(
                                      lang,
                                      "verse_search_input_label",
                                    ),
                                    hintText: generator.getLocaleString(
                                      lang,
                                      "verse_search_hint",
                                    ),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    suffixIconConstraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                    suffixIcon: value.text.isNotEmpty
                                        ? IconButton(
                                            constraints: const BoxConstraints(
                                              minWidth: 48,
                                              minHeight: 48,
                                            ),
                                            icon: const Icon(Icons.clear),
                                            tooltip: generator.getLocaleString(
                                              lang,
                                              "clear_search_tooltip",
                                            ),
                                            onPressed: searching
                                                ? null
                                                : () {
                                                    _verseSearchController
                                                        .clear();
                                                    setDialogState(() {
                                                      results = const [];
                                                      hasSearched = false;
                                                    });
                                                  },
                                          )
                                        : null,
                                  ),
                                  onSubmitted: runSearch,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: canSearch
                                    ? () =>
                                          runSearch(_verseSearchController.text)
                                    : null,
                                child: Text(
                                  generator.getLocaleString(
                                    lang,
                                    "verse_search_submit",
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: themeKeys.map((key) {
                          final String label = generator.getLocaleString(
                            lang,
                            key,
                          );
                          return ActionChip(
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                            label: Text(label),
                            onPressed: searching
                                ? null
                                : () {
                                    HapticFeedback.selectionClick();
                                    _verseSearchController.text = label;
                                    runSearch(label);
                                  },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      if (searching)
                        Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                semanticsLabel: generator.getLocaleString(
                                  lang,
                                  "searching_verses_semantics",
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (!hasSearched)
                        Text(
                          generator.getLocaleString(
                            lang,
                            "verse_search_prompt",
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else if (results.isEmpty)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            generator.getLocaleString(
                              lang,
                              "verse_search_empty",
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: results.length,
                            separatorBuilder: (_, _) =>
                                const ExcludeSemantics(
                                  child: Divider(height: 1),
                                ),
                            itemBuilder: (context, index) {
                              final BibleSearchResult item = results[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                title: Text(
                                  item.reference,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  item.text,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.of(dialogContext).pop(item);
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    generator.getLocaleString(lang, "gemini_cancel_btn"),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        selectedBook = picked.bookName;
        selectedChapter = picked.chapter;
        selectedVerse = picked.verse;
        selectedEndVerse = null;
        referenceController.text = picked.reference;
        verseController.text = picked.text;
        _updateStatus(
          "${picked.reference} — ${generator.getLocaleString(lang, "success_msg")}",
          forceSuccess: true,
        );
      });
    }
  }

  Future<void> _launchExternalUrl(Uri uri, String lang) async {
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            generator.getLocaleString(lang, "url_launch_error_msg"),
          ),
        ),
      );
    }
  }

  Future<void> _showAboutDialog() async {
    final String lang = getLangKey();
    final ThemeData theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.menu_book_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(generator.getLocaleString(lang, "about_title")),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  generator.getLocaleString(lang, "about_description"),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Card.outlined(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            generator.getLocaleString(
                              lang,
                              "about_youversion_heading",
                            ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          generator.getLocaleString(
                            lang,
                            "about_youversion_credit",
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () => _launchExternalUrl(
                            Uri.parse(GetBibleAPI.youVersionPortalUrl),
                            lang,
                          ),
                          icon: const ExcludeSemantics(
                            child: Icon(Icons.open_in_new, size: 16),
                          ),
                          label: Text(
                            generator.getLocaleString(
                              lang,
                              "about_visit_youversion_btn",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card.outlined(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            generator.getLocaleString(
                              lang,
                              "about_accessibility_heading",
                            ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          generator.getLocaleString(
                            lang,
                            "about_accessibility_summary",
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: () => _launchExternalUrl(
                                Uri.parse(accessibilityStatementUrl),
                                lang,
                              ),
                              icon: const ExcludeSemantics(
                                child: Icon(Icons.accessibility_new, size: 16),
                              ),
                              label: Text(
                                generator.getLocaleString(
                                  lang,
                                  "about_accessibility_statement_btn",
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: () => _launchExternalUrl(
                                Uri.parse(privacyPolicyUrl),
                                lang,
                              ),
                              icon: const ExcludeSemantics(
                                child: Icon(
                                  Icons.privacy_tip_outlined,
                                  size: 16,
                                ),
                              ),
                              label: Text(
                                generator.getLocaleString(
                                  lang,
                                  "about_privacy_policy_btn",
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  generator.getLocaleString(lang, "about_other_sources"),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(generator.getLocaleString(lang, "gemini_cancel_btn")),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sampleCurrentBackgroundLuminance() async {
    final int seq = ++_sampleSeq;
    final String safeBgName = selectedBackground
        .split('/')
        .last
        .split('\\')
        .last;
    final BackgroundLuminanceProfile? profile = customImagePath != null
        ? await contrastSampler.sampleFile(customImagePath!)
        : await contrastSampler.sampleAsset(
            'assets/backgrounds/$safeBgName',
          );
    if (!mounted || seq != _sampleSeq) return;
    setState(() {
      _sampledBgProfile = profile;
    });
  }

  Future<void> _listenForVerseByVoice() async {
    if (!_voiceInputAvailable || _isListeningVoice) return;
    HapticFeedback.lightImpact();
    final String lang = getLangKey();
    final String locale = TtsService.resolveTargetLocale(getAudioLangKey());
    setState(() {
      _isListeningVoice = true;
    });
    final List<String> candidates = await voiceVerseService
        .listenForVerseCandidates(
          locale: locale,
          prompt: generator.getLocaleString(lang, "voice_verse_prompt"),
        );
    if (!mounted) return;
    setState(() {
      _isListeningVoice = false;
    });
    if (candidates.isEmpty) return;
    final String normalized = VoiceVerseService.selectBestCandidate(
      candidates,
      lang: bibleLang,
    );
    if (normalized.isEmpty) return;
    referenceController.text = normalized;
    setState(() {
      _syncSelectorsFromReference(normalized);
      _updateStatus(
        generator
            .getLocaleString(lang, "voice_verse_heard_msg")
            .replaceAll("{ref}", normalized),
      );
    });
    await _fetchVerse();
  }

  Future<void> _toggleAudioPreview() async {
    HapticFeedback.selectionClick();
    if (isPlayingAudioPreview) {
      await ttsService.stop();
      setState(() {
        isPlayingAudioPreview = false;
        _spokenWordRange = null;
      });
      return;
    }

    final String verse = verseController.text.trim();
    if (verse.isEmpty) return;

    setState(() {
      isPlayingAudioPreview = true;
      _spokenWordRange = null;
    });
    await ttsService.speakPreview(
      verse: verse,
      reference: referenceController.text.trim(),
      lang: getAudioLangKey(),
      gender: gender,
      speechRate: TtsService.documentarySpeechRate * _ttsSpeedMultiplier,
      onWordProgress: (int start, int end) {
        if (!mounted || !isPlayingAudioPreview) return;
        setState(() {
          _spokenWordRange = (start, end);
        });
      },
    );
    if (mounted) {
      setState(() {
        isPlayingAudioPreview = false;
        _spokenWordRange = null;
      });
    }
  }

  String? get _activeImageDescription {
    final String manual = _imageDescriptionController.text.trim();
    if (manual.isNotEmpty) return manual;
    if (_geminiNanoAvailability.isCompatible &&
        _geminiNanoEnabled &&
        _onDeviceImageDescription != null &&
        _onDeviceImageDescription!.trim().isNotEmpty) {
      return _onDeviceImageDescription!.trim();
    }
    return null;
  }

  Future<void> _describeCurrentBackgroundWithGeminiNano() async {
    if (!_geminiNanoAvailability.isCompatible ||
        !_geminiNanoEnabled ||
        _isDescribingImage) {
      return;
    }
    final String lang = getLangKey();
    setState(() {
      _isDescribingImage = true;
      _updateStatus(generator.getLocaleString(lang, "gemini_nano_describing_msg"));
    });

    GeminiNanoDescriptionResult result;
    try {
      if (customImagePath != null) {
        result = await geminiNanoService.describeImageFile(
          customImagePath!,
          targetLanguage: lang,
        );
      } else {
        final String safeBgName = selectedBackground
            .split('/')
            .last
            .split('\\')
            .last;
        final ByteData assetData = await rootBundle.load(
          'assets/backgrounds/$safeBgName',
        );
        result = await geminiNanoService.describeImageBytes(
          assetData.buffer.asUint8List(),
          targetLanguage: lang,
        );
      }
    } catch (_) {
      result = const GeminiNanoDescriptionResult(errorCode: 'inference_error');
    }

    if (!mounted) return;
    setState(() {
      _isDescribingImage = false;
      if (result.isSuccess) {
        _onDeviceImageDescription = result.description;
        _imageDescriptionController.text = result.description!;
        _geminiNanoAvailability = GeminiNanoAvailability.available;
        _updateStatus(
          generator.getLocaleString(lang, "gemini_nano_success_msg"),
          forceSuccess: true,
        );
      } else if (result.errorCode == 'downloading') {
        _geminiNanoAvailability = GeminiNanoAvailability.downloading;
        _updateStatus(
          generator.getLocaleString(lang, "gemini_nano_downloading_msg"),
        );
      } else if (result.errorCode == 'translation_failed') {
        _updateStatus(
          generator.getLocaleString(lang, "gemini_nano_translation_error_msg"),
          forceError: true,
        );
      } else {
        _updateStatus(
          generator.getLocaleString(lang, "gemini_nano_error_msg"),
          forceError: true,
        );
      }
    });
  }

  Future<void> _shareToGemini(GeminiHandoffTask task) async {
    final String verse = verseController.text.trim();
    final String reference = referenceController.text.trim();
    if (verse.isEmpty || reference.isEmpty) return;

    HapticFeedback.lightImpact();
    final String lang = getLangKey();
    final String prompt = geminiHandoffService.buildPrompt(
      lang: lang,
      verse: verse,
      reference: reference,
      aspectRatio: aspectRatioStr,
      task: task,
    );
    final bool shared = await geminiHandoffService.shareToGemini(
      prompt: prompt,
      imagePath: task == GeminiHandoffTask.devotionalCaption
          ? customImagePath
          : null,
    );
    if (!mounted) return;
    if (!shared) {
      setState(() {
        _updateStatus(
          generator.getLocaleString(lang, "gemini_handoff_error_msg"),
          forceError: true,
        );
      });
    }
  }

  Future<void> _copyAndOpenGemini(GeminiHandoffTask task) async {
    final String verse = verseController.text.trim();
    final String reference = referenceController.text.trim();
    if (verse.isEmpty || reference.isEmpty) return;

    HapticFeedback.lightImpact();
    final String lang = getLangKey();
    final String prompt = geminiHandoffService.buildPrompt(
      lang: lang,
      verse: verse,
      reference: reference,
      aspectRatio: aspectRatioStr,
      task: task,
    );
    final bool opened = await geminiHandoffService.copyAndOpenGemini(
      prompt: prompt,
    );
    if (!mounted) return;
    setState(() {
      _updateStatus(
        opened
            ? generator.getLocaleString(lang, "gemini_handoff_copied_msg")
            : generator.getLocaleString(lang, "gemini_handoff_error_msg"),
        forceSuccess: opened,
        forceError: !opened,
      );
    });
  }

  Future<void> _showAdvancedFeaturesDialog() async {
    final String lang = getLangKey();
    final bool nanoCompatible = _geminiNanoAvailability.isCompatible;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                generator.getLocaleString(lang, "advanced_features_title"),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      generator.getLocaleString(
                        lang,
                        "advanced_features_subtitle",
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (nanoCompatible)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          generator.getLocaleString(
                            lang,
                            "gemini_nano_toggle_title",
                          ),
                        ),
                        subtitle: Text(
                          generator.getLocaleString(
                            lang,
                            _geminiNanoAvailability ==
                                    GeminiNanoAvailability.available
                                ? "gemini_nano_toggle_subtitle"
                                : "gemini_nano_toggle_subtitle_download",
                          ),
                        ),
                        value: _geminiNanoEnabled,
                        onChanged: (bool value) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _geminiNanoEnabled = value;
                            if (!value) {
                              _onDeviceImageDescription = null;
                            }
                          });
                          setDialogState(() {});
                          unawaited(_saveAdvancedPreferences());
                        },
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        generator.getLocaleString(
                          lang,
                          "gemini_handoff_toggle_title",
                        ),
                      ),
                      subtitle: Text(
                        generator.getLocaleString(
                          lang,
                          "gemini_handoff_toggle_subtitle",
                        ),
                      ),
                      value: _geminiHandoffEnabled,
                      onChanged: (bool value) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _geminiHandoffEnabled = value;
                        });
                        setDialogState(() {});
                        unawaited(_saveAdvancedPreferences());
                      },
                    ),
                    const ExcludeSemantics(child: Divider()),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        generator.getLocaleString(
                          lang,
                          "high_contrast_ui_title",
                        ),
                      ),
                      subtitle: Text(
                        generator.getLocaleString(
                          lang,
                          "high_contrast_ui_subtitle",
                        ),
                      ),
                      value: _highContrastUiEnabled,
                      onChanged: (bool value) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _highContrastUiEnabled = value;
                        });
                        widget.onHighContrastChanged?.call(value);
                        setDialogState(() {});
                        unawaited(_saveAdvancedPreferences());
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        generator.getLocaleString(
                          lang,
                          "color_blind_ui_title",
                        ),
                      ),
                      subtitle: Text(
                        generator.getLocaleString(
                          lang,
                          "color_blind_ui_subtitle",
                        ),
                      ),
                      value: _colorBlindUiEnabled,
                      onChanged: (bool value) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _colorBlindUiEnabled = value;
                        });
                        setDialogState(() {});
                        unawaited(_saveAdvancedPreferences());
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    generator.getLocaleString(lang, "gemini_cancel_btn"),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateContent() async {
    final String verse = verseController.text.trim();
    final String reference = referenceController.text.trim();

    if (verse.isEmpty || reference.isEmpty) return;

    final String lang = getLangKey();
    setState(() {
      isGenerating = true;
      _updateStatus(generator.getLocaleString(lang, "generating_content_msg"));
    });

    final Map<String, String> texts = await generator.generateTexts(
      lang,
      verse,
      reference,
      customDescription: _activeImageDescription,
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
        speechRate: TtsService.documentarySpeechRate * _ttsSpeedMultiplier,
      );
    }

    final bool exported = await mediaExportService.captureSaveAndShareImage(
      boundaryKey: _globalKey,
      altText: altText,
      caption: caption,
      audioPath: audioPath,
    );

    if (!mounted) return;
    setState(() {
      isGenerating = false;
      if (exported) {
        _updateStatus(
          generator.getLocaleString(lang, "success_msg"),
          forceSuccess: true,
        );
      } else {
        _updateStatus(
          generator.getLocaleString(lang, "error_msg"),
          forceError: true,
        );
      }
    });
  }

  void _copyToClipboard(String text, {String? fieldKey}) {
    HapticFeedback.lightImpact();
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
    ScaffoldMessenger.of(context).clearSnackBars();
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
    // ⚡ Bolt: Precompute lowercase book titles once per modal open instead of 66x per keystroke
    final List<MapEntry<String, String>> indexedBooks = [
      for (final b in canonicalBooks) MapEntry(b, b.toLowerCase()),
    ];
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
                : [
                    for (final entry in indexedBooks)
                      if (entry.value.contains(query)) entry.key,
                  ];

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
                        maxLength: 100,
                        decoration: InputDecoration(
                          counterText: "",
                          prefixIcon: const ExcludeSemantics(
                            child: Icon(Icons.search),
                          ),
                          labelText: generator.getLocaleString(
                            lang,
                            "search_book_label",
                          ),
                          hintText: generator.getLocaleString(
                            lang,
                            "search_book_hint",
                          ),
                          border: const OutlineInputBorder(),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          suffixIcon: query.isNotEmpty
                              ? IconButton(
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  icon: const Icon(Icons.clear),
                                  tooltip: generator.getLocaleString(
                                    lang,
                                    "clear_search_tooltip",
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
                        child: filtered.isEmpty
                            ? Semantics(
                                liveRegion: true,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.search_off,
                                          size: 40,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          generator.getLocaleString(
                                            lang,
                                            "book_search_empty",
                                          ),
                                          textAlign: TextAlign.center,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                        if (query.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(0, 48),
                                            ),
                                            onPressed: () {
                                              searchController.clear();
                                              setSheetState(() {});
                                            },
                                            icon: const Icon(
                                              Icons.clear,
                                              size: 18,
                                            ),
                                            label: Text(
                                              generator.getLocaleString(
                                                lang,
                                                "clear_btn",
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final String book = filtered[index];
                                  final bool isSelected = book == selectedBook;
                                  return ListTile(
                                    selected: isSelected,
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
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          )
                                        : null,
                                    onTap: () {
                                      setState(() {
                                        selectedBook = book;
                                        selectedChapter = 1;
                                        selectedVerse = 1;
                                        selectedEndVerse = null;
                                        _onQuickReferenceChanged();
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

  Color _successColor(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (_colorBlindUiEnabled) {
      return isDark ? const Color(0xFF64B5F6) : const Color(0xFF0057B8);
    }
    return isDark ? Colors.green.shade300 : Colors.green.shade800;
  }

  Color _errorColor(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (_colorBlindUiEnabled) {
      return isDark ? const Color(0xFFFFB74D) : const Color(0xFFC85A00);
    }
    return Theme.of(context).colorScheme.error;
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
        // Compact Bible language pill + Mic + Search Topic + Version selector row
        LayoutBuilder(
          builder: (context, constraints) {
            final Widget bibleLangPicker = Semantics(
              label:
                  "${generator.getLocaleString(lang, "bible_lang_label")}: ${_fullBibleLangLabel(bibleLang)}",
              child: Container(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 76),
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.language,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isDense: true,
                        itemHeight: null,
                        iconSize: 18,
                        value: bibleLang,
                        selectedItemBuilder: (BuildContext context) {
                          return _bibleLangCodes
                              .map<Widget>(
                                (String code) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _shortBibleLangCode(code),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              )
                              .toList();
                        },
                        onChanged: (String? newCode) {
                          if (newCode != null && newCode != bibleLang) {
                            _switchBibleLanguage(newCode);
                          }
                        },
                        items: _bibleLangCodes
                            .map<DropdownMenuItem<String>>(
                              (String code) => DropdownMenuItem<String>(
                                value: code,
                                child: Text(
                                  _fullBibleLangLabel(code),
                                  style: Theme.of(context).textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );

            final Widget? micButton = _voiceInputAvailable
                ? IconButton.filledTonal(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    tooltip: generator.getLocaleString(
                      lang,
                      "voice_verse_tooltip",
                    ),
                    onPressed: _isListeningVoice || isFetching
                        ? null
                        : _listenForVerseByVoice,
                    icon: _isListeningVoice
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.mic),
                  )
                : null;

            final Widget searchTopicButton = IconButton.filledTonal(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: generator.getLocaleString(lang, "verse_search_btn"),
              onPressed: isFetching ? null : _showVerseSearchDialog,
              icon: const Icon(Icons.search),
            );

            final Widget versionDropdown = Semantics(
              label: generator.getLocaleString(lang, "bible_version_label"),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: DropdownButton<String>(
                  isExpanded: true,
                  itemHeight: null,
                  value: selectedBibleVersion,
                  items: bibleVersions
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => selectedBibleVersion = v);
                    _savePreferredBibleVersion(bibleLang, v);
                    if (referenceController.text.trim().isNotEmpty) {
                      _fetchVerse();
                    }
                  },
                ),
              ),
            );

            final double textScale = MediaQuery.textScalerOf(context).scale(1.0);
            final bool singleRow =
                constraints.maxWidth >= 320 && textScale <= 1.3;

            if (singleRow) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  bibleLangPicker,
                  if (micButton != null) ...[
                    const SizedBox(width: 6),
                    micButton,
                  ],
                  const SizedBox(width: 6),
                  searchTopicButton,
                  const SizedBox(width: 8),
                  Expanded(child: versionDropdown),
                ],
              );
            }

            return Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                bibleLangPicker,
                ?micButton,
                searchTopicButton,
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: versionDropdown,
                ),
              ],
            );
          },
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
                        Flexible(
                          child: Semantics(
                            label: generator.getLocaleString(
                              lang,
                              "book_label",
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: DropdownButton<String>(
                                isExpanded: true,
                                itemHeight: null,
                                value: selectedBook,
                                items: _getBookDropdownItems(
                                  bibleLang,
                                  canonicalBooks,
                                ),
                                onChanged: (b) {
                                  setState(() {
                                    selectedBook = b;
                                    selectedChapter = 1;
                                    selectedVerse = 1;
                                    selectedEndVerse = null;
                                    _onQuickReferenceChanged();
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
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
                        Flexible(
                          child: ExcludeSemantics(
                            child: Text(
                              "${generator.getLocaleString(lang, "chapter_label")}: ",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Semantics(
                          label: generator.getLocaleString(
                            lang,
                            "chapter_label",
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: DropdownButton<int>(
                              itemHeight: null,
                              value: selectedChapter,
                              menuMaxHeight: 320,
                              items: _getChapterDropdownItems(maxChapters),
                              onChanged: (ch) {
                                if (ch != null) {
                                  setState(() {
                                    selectedChapter = ch;
                                    selectedVerse = 1;
                                    selectedEndVerse = null;
                                    _onQuickReferenceChanged();
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: ExcludeSemantics(
                            child: Text(
                              "${generator.getLocaleString(lang, "verse_num_label")}: ",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Semantics(
                          label: generator.getLocaleString(
                            lang,
                            "verse_num_label",
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: DropdownButton<int>(
                              itemHeight: null,
                              value: selectedVerse,
                              menuMaxHeight: 320,
                              items: _getVerseDropdownItems(maxVerses),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    selectedVerse = v;
                                    if (selectedEndVerse != null &&
                                        selectedEndVerse! <= v) {
                                      selectedEndVerse = null;
                                    }
                                    _onQuickReferenceChanged();
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (selectedVerse < maxVerses)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: ExcludeSemantics(
                              child: Text(
                                "${generator.getLocaleString(lang, "verse_end_label")}: ",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Semantics(
                            label: generator.getLocaleString(
                              lang,
                              "verse_end_label",
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: DropdownButton<int?>(
                                itemHeight: null,
                                value: selectedEndVerse,
                              menuMaxHeight: 320,
                              items: _getEndVerseDropdownItems(
                                lang,
                                selectedVerse,
                                maxVerses,
                              ),
                              onChanged: (endV) {
                                setState(() {
                                  selectedEndVerse = endV;
                                  _onQuickReferenceChanged();
                                });
                              },
                            ),
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
        // Verse of the Day action row right after Book/Chapter/Verse
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
              ),
              onPressed:
                  isFetching || selectedBibleVersion == "-"
                      ? null
                      : _fetchVerseOfTheDay,
              icon: isFetching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wb_sunny_outlined, size: 18),
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
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) {
                if (!isFetching &&
                    selectedBibleVersion != "-" &&
                    referenceController.text.trim().isNotEmpty) {
                  _fetchVerse();
                }
              },
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                labelText: generator.getLocaleString(lang, "reference_label"),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                suffixIcon: value.text.isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: isFetching
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download, size: 20),
                            tooltip: generator.getLocaleString(
                              lang,
                              "fetch_verse_btn",
                            ),
                            onPressed:
                                isFetching || selectedBibleVersion == "-"
                                ? null
                                : _fetchVerse,
                          ),
                          IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: const Icon(Icons.clear),
                            tooltip: generator.getLocaleString(
                              lang,
                              "clear_reference_tooltip",
                            ),
                            onPressed: referenceController.clear,
                          ),
                        ],
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
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                suffixIcon: value.text.isNotEmpty
                    ? IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: const Icon(Icons.clear),
                        tooltip: generator.getLocaleString(
                          lang,
                          "clear_verse_tooltip",
                        ),
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

  String _formatBackgroundName(String fileName) {
    final String base = fileName.replaceAll(_fileExtensionRegExp, '');
    return base
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  Widget _buildBackgroundTab(String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            ExcludeSemantics(
              child: Text(
                generator.getLocaleString(lang, "background_label"),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Semantics(
              label: generator.getLocaleString(lang, "background_label"),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: DropdownButton<String>(
                  itemHeight: null,
                  value: customImagePath == null ? selectedBackground : null,
                  hint: Text(
                    generator.getLocaleString(
                      lang,
                      "custom_bg_active_label",
                    ),
                  ),
                  items: _getBackgroundDropdownItems(),
                  onChanged: (v) {
                    setState(() {
                      selectedBackground = v!;
                      customImagePath = null;
                      _onDeviceImageDescription = null;
                      _imageDescriptionController.clear();
                    });
                    unawaited(_sampleCurrentBackgroundLuminance());
                  },
                ),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
              ),
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
            itemCount: backgrounds.length + (customImagePath != null ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (customImagePath != null && index == 0) {
                final String activeLabel = generator.getLocaleString(
                  lang,
                  "custom_bg_active_label",
                );
                return Semantics(
                  image: true,
                  selected: true,
                  label: activeLabel,
                  child: Tooltip(
                    message: activeLabel,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                        ),
                        image: DecorationImage(
                          image: ResizeImage(
                            FileImage(File(customImagePath!)),
                            width: 204,
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: ExcludeSemantics(
                            child: Icon(
                              Icons.check,
                              size: 14,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
              final String bgName =
                  backgrounds[customImagePath != null ? index - 1 : index];
              final String safeBgName = bgName
                  .split('/')
                  .last
                  .split('\\')
                  .last;
              final bool isSelected =
                  customImagePath == null && selectedBackground == bgName;
              final String label = _getBackgroundLabel(safeBgName);
              return Semantics(
                button: true,
                selected: isSelected,
                label: label,
                child: Tooltip(
                  message: label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        selectedBackground = bgName;
                        customImagePath = null;
                        _onDeviceImageDescription = null;
                        _imageDescriptionController.clear();
                      });
                      unawaited(_sampleCurrentBackgroundLuminance());
                    },
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
                          // ⚡ Bolt: Decode 68x68 background strip thumbnails at 3x display width
                          image: ResizeImage(
                            AssetImage("assets/backgrounds/$safeBgName"),
                            width: 204,
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: isSelected
                          ? Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: ExcludeSemantics(
                                  child: Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildBackgroundToneBadge(lang),
        const SizedBox(height: 12),
        ValueListenableBuilder<double>(
          valueListenable: _backgroundDimNotifier,
          builder: (context, dimValue, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${generator.getLocaleString(lang, "background_dim_label")}: ${(dimValue * 100).round()}%",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      tooltip: generator.getLocaleString(
                        lang,
                        "decrease_dim_tooltip",
                      ),
                      onPressed: dimValue > 0.01
                          ? () {
                              HapticFeedback.selectionClick();
                              _backgroundDimNotifier.value =
                                  ((dimValue - 0.05).clamp(0.0, 0.75) * 20)
                                      .round() /
                                  20.0;
                            }
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Expanded(
                      child: Slider(
                        value: dimValue,
                        min: 0.0,
                        max: 0.75,
                        divisions: 15,
                        label: "${(dimValue * 100).round()}%",
                        semanticFormatterCallback: (v) =>
                            "${generator.getLocaleString(lang, "background_dim_label")}: ${(v * 100).round()}%",
                        onChanged: (v) => _backgroundDimNotifier.value = v,
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      tooltip: generator.getLocaleString(
                        lang,
                        "increase_dim_tooltip",
                      ),
                      onPressed: dimValue < 0.74
                          ? () {
                              HapticFeedback.selectionClick();
                              _backgroundDimNotifier.value =
                                  ((dimValue + 0.05).clamp(0.0, 0.75) * 20)
                                      .round() /
                                  20.0;
                            }
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        if (_geminiHandoffEnabled) ...[
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _previewListenable,
            builder: (context, _) {
              final bool hasVerse =
                  verseController.text.trim().isNotEmpty &&
                  referenceController.text.trim().isNotEmpty;
              return OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                onPressed: hasVerse
                    ? () => _copyAndOpenGemini(
                        GeminiHandoffTask.customBackground,
                      )
                    : null,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  generator.getLocaleString(lang, "gemini_handoff_bg_btn"),
                ),
              );
            },
          ),
        ],
        _buildContrastWarningCard(lang, tabIndex: 1),
        _buildStepNavigationRow(lang, 1),
      ],
    );
  }

  Future<void> _showFullScreenPreview(String lang) async {
    VisionSimulationMode simMode = VisionSimulationMode.normal;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(
                  title: Text(
                    generator.getLocaleString(lang, "fullscreen_preview_title"),
                  ),
                  leading: IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: const Icon(Icons.close),
                    tooltip: generator.getLocaleString(
                      lang,
                      "gemini_cancel_btn",
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
                body: SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: VisionSimulatorFilter(
                              mode: simMode,
                              child: VersePreviewCard(
                                repaintKey: GlobalKey(),
                                aspectRatioStr: aspectRatioStr,
                                customImagePath: customImagePath,
                                selectedBackground: selectedBackground,
                                previewListenable: _previewListenable,
                                verseController: verseController,
                                referenceController: referenceController,
                                fontColor: _fontColorNotifier.value,
                                fontSize: _fontSizeNotifier.value,
                                yOffset: _yOffsetNotifier.value,
                                backgroundDim: _backgroundDimNotifier.value,
                                textStyleOptions: _textStyleNotifier.value,
                                fontColorListenable: _fontColorNotifier,
                                fontSizeListenable: _fontSizeNotifier,
                                yOffsetListenable: _yOffsetNotifier,
                                backgroundDimListenable: _backgroundDimNotifier,
                                textStyleListenable: _textStyleNotifier,
                                onYOffsetChanged: (updated) =>
                                    _yOffsetNotifier.value = updated,
                                lang: lang,
                                bibleLang: bibleLang,
                                generator: generator,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                generator.getLocaleString(
                                  lang,
                                  "vision_sim_label",
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: VisionSimulationMode.values.map((m) {
                                return ChoiceChip(
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.padded,
                                  label: Text(
                                    generator.getLocaleString(
                                      lang,
                                      m.localeKey,
                                    ),
                                  ),
                                  selected: simMode == m,
                                  onSelected: (_) {
                                    HapticFeedback.selectionClick();
                                    setDialogState(() => simMode = m);
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _effectiveBackgroundLuminance() {
    final double dimValue = _backgroundDimNotifier.value;
    final Color currentFontColor = _fontColorNotifier.value;
    final double fgLuminance = currentFontColor.computeLuminance();
    final VerseTextStyleOptions style = _textStyleNotifier.value;

    final double baseBgLuminance;
    if (_sampledBgProfile != null) {
      final double meanLum = _sampledBgProfile!.luminanceForOffset(
        _yOffsetNotifier.value,
      );
      final double worstLum = _sampledBgProfile!.worstCaseLuminanceFor(
        _yOffsetNotifier.value,
        fgLuminance,
      );
      baseBgLuminance = (meanLum + worstLum) * 0.5;
    } else {
      final bool isDarkPreset =
          customImagePath == null &&
          (selectedBackground == "minimal_slate.png" ||
              selectedBackground == "starry_night.png");
      final bool isLightPreset =
          customImagePath == null &&
          (selectedBackground == "soft_parchment.png" ||
              selectedBackground == "dawn_sky.png");
      baseBgLuminance = isDarkPreset
          ? 0.06
          : (isLightPreset ? 0.62 : 0.26);
    }

    double effectiveBgLuminance = baseBgLuminance * (1.0 - dimValue);
    if (style.backdrop == VerseTextBackdrop.frosted) {
      final bool darkText = fgLuminance < 0.4;
      effectiveBgLuminance = darkText
          ? effectiveBgLuminance * 0.28 + 0.72
          : effectiveBgLuminance * 0.58;
    } else if (style.backdrop == VerseTextBackdrop.solid) {
      final bool darkText = fgLuminance < 0.4;
      effectiveBgLuminance = darkText
          ? effectiveBgLuminance * 0.10 + 0.90
          : effectiveBgLuminance * 0.22;
    }
    return effectiveBgLuminance.clamp(0.0, 1.0);
  }

  /// Resolves the representative background [Color] (accounting for sampled
  /// RGB pixels, dim overlay, and text backdrop) so CVD contrast checks catch
  /// real chromatic collisions (e.g. red text over a green photograph).
  Color _effectiveBackgroundColor(double effectiveBgLum) {
    final Color? sampledColor = _sampledBgProfile?.colorForOffset(
      _yOffsetNotifier.value,
    );
    if (sampledColor == null) {
      return ColorAccessibility.grayscaleColorForLuminance(effectiveBgLum);
    }
    final double dimValue = _backgroundDimNotifier.value.clamp(0.0, 0.85);
    Color effective = Color.lerp(sampledColor, Colors.black, dimValue) ??
        sampledColor;
    final VerseTextStyleOptions style = _textStyleNotifier.value;
    final bool darkText = _fontColorNotifier.value.computeLuminance() < 0.4;
    if (style.backdrop == VerseTextBackdrop.frosted) {
      effective =
          Color.lerp(
            effective,
            darkText ? Colors.white : Colors.black,
            darkText ? 0.72 : 0.42,
          ) ??
          effective;
    } else if (style.backdrop == VerseTextBackdrop.solid) {
      effective =
          Color.lerp(
            effective,
            darkText ? Colors.white : Colors.black,
            darkText ? 0.90 : 0.78,
          ) ??
          effective;
    }
    return effective;
  }

  void _applySuggestedSafeColor(String lang) {
    HapticFeedback.selectionClick();
    final Color approxBg = _effectiveBackgroundColor(
      _effectiveBackgroundLuminance(),
    );
    final result = ColorAccessibility.suggestSafestTextColor(
      candidates: _presetColors,
      backgroundColor: approxBg,
    );
    _fontColorNotifier.value = result.entry.key;
    final String colorName = generator.getLocaleString(
      lang,
      result.entry.value,
    );
    setState(() {
      _updateStatus(
        generator
            .getLocaleString(lang, "safe_color_applied_msg")
            .replaceAll("{color}", colorName),
        forceSuccess: true,
      );
    });
  }

  Widget _buildBackgroundToneBadge(String lang) {
    return AnimatedBuilder(
      animation: _contrastListenable,
      builder: (context, _) {
        // ⚡ Bolt: Skip tone badge luminance calculations & widget builds when Background tab (1) is inactive
        if (_selectedTabIndex != 1) {
          return const SizedBox.shrink();
        }
        final double bgLum = _effectiveBackgroundLuminance();
        final bool isDark = bgLum < 0.22;
        final bool isLight = bgLum > 0.55;
        final IconData icon = isDark
            ? Icons.dark_mode_outlined
            : (isLight ? Icons.light_mode_outlined : Icons.contrast);
        final String label = generator.getLocaleString(
          lang,
          isDark
              ? "bg_tone_dark"
              : (isLight ? "bg_tone_light" : "bg_tone_balanced"),
        );
        return Semantics(
          label: label,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    icon,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContrastWarningCard(String lang, {required int tabIndex}) {
    return AnimatedBuilder(
      animation: _contrastListenable,
      builder: (context, _) {
        // ⚡ Bolt: Skip WCAG/CVD contrast & placement math when this tab is hidden inside IndexedStack
        if (_selectedTabIndex != tabIndex) {
          return const SizedBox.shrink();
        }
        final double dimValue = _backgroundDimNotifier.value;
        final Color currentFontColor = _fontColorNotifier.value;
        final double fgLuminance = currentFontColor.computeLuminance();
        final VerseTextStyleOptions style = _textStyleNotifier.value;

        final double effectiveBgLum = _effectiveBackgroundLuminance();
        final double contrastRatio = VersePreviewCard.computeWcagContrastRatio(
          fgLuminance,
          effectiveBgLum,
        );
        final Color approxBgColor = _effectiveBackgroundColor(effectiveBgLum);
        final cvdCheck = ColorAccessibility.worstCaseCvdContrast(
          textColor: currentFontColor,
          backgroundColor: approxBgColor,
        );
        final String ratioStr = contrastRatio.toStringAsFixed(1);
        final bool lowContrast = contrastRatio < 4.5;
        final bool cvdLowContrast = !lowContrast && cvdCheck.minRatio < 4.5;
        final bool isAaa = contrastRatio >= 7.0 && cvdCheck.minRatio >= 7.0;

        ({double yOffset, double ratio})? smartPlacement;
        if (_sampledBgProfile != null &&
            style.backdrop == VerseTextBackdrop.none) {
          final candidate = _sampledBgProfile!.bestPlacementFor(
            fontColor: currentFontColor,
            dim: dimValue,
          );
          if (candidate.ratio >= contrastRatio + 0.8 &&
              (candidate.yOffset - _yOffsetNotifier.value).abs() > 25.0) {
            smartPlacement = candidate;
          }
        }

        if (cvdLowContrast) {
          final String modeName = generator.getLocaleString(
            lang,
            cvdCheck.worstMode.localeKey,
          );
          final String cvdMsg = generator
              .getLocaleString(lang, "cvd_contrast_warning")
              .replaceAll("{mode}", modeName)
              .replaceAll("{ratio}", cvdCheck.minRatio.toStringAsFixed(1));
          return Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              Icons.remove_red_eye_outlined,
                              size: 20,
                              color: Theme.of(
                                context,
                              ).colorScheme.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cvdMsg,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onTertiaryContainer,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onTertiaryContainer,
                        ),
                        onPressed: () => _applySuggestedSafeColor(lang),
                        child: Text(
                          generator.getLocaleString(
                            lang,
                            "suggest_safe_color_btn",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (!lowContrast) {
          final Color badgeColor = isAaa
              ? _successColor(context)
              : Theme.of(context).colorScheme.primary;
          final double renderedPt = _fontSizeNotifier.value / 2.0;
          final bool isLargeText =
              renderedPt >= 18.0 || (style.isBold && renderedPt >= 14.0);
          final String sizeTag = generator.getLocaleString(
            lang,
            isLargeText ? "wcag_large_text_tag" : "wcag_normal_text_tag",
          );
          final String baseBadgeLabel = generator
              .getLocaleString(
                lang,
                isAaa ? "wcag_contrast_aaa" : "wcag_contrast_aa",
              )
              .replaceAll("{ratio}", ratioStr);
          final String badgeLabel = sizeTag.isNotEmpty
              ? "$baseBadgeLabel · $sizeTag"
              : baseBadgeLabel;
          return Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Semantics(
                  label: badgeLabel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            isAaa ? Icons.verified : Icons.check_circle_outline,
                            size: 18,
                            color: badgeColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            badgeLabel,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: badgeColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (smartPlacement != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _yOffsetNotifier.value = smartPlacement!.yOffset;
                    },
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: Text(
                      generator.getLocaleString(lang, "smart_placement_btn"),
                    ),
                  ),
              ],
            ),
          );
        }

        final String lowContrastMsg = generator
            .getLocaleString(lang, "wcag_contrast_low")
            .replaceAll("{ratio}", ratioStr);
        return Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Card(
              margin: EdgeInsets.zero,
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            Icons.contrast,
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onTertiaryContainer,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lowContrastMsg,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onTertiaryContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (smartPlacement != null)
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onTertiaryContainer,
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _yOffsetNotifier.value = smartPlacement!.yOffset;
                            },
                            child: Text(
                              generator.getLocaleString(
                                lang,
                                "smart_placement_btn",
                              ),
                            ),
                          ),
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onTertiaryContainer,
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            if (fgLuminance > 0.5) {
                              _backgroundDimNotifier.value =
                                  dimValue < 0.35 ? 0.35 : 0.60;
                            } else {
                              _updateTextStyle(
                                style.copyWith(
                                  backdrop: VerseTextBackdrop.solid,
                                ),
                              );
                            }
                          },
                          child: Text(
                            generator.getLocaleString(lang, "contrast_fix_btn"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
        Semantics(
          header: true,
          child: Text(
            generator.getLocaleString(lang, "aspect_ratio_label"),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ratios.map((r) {
            final String val = r["value"]!;
            final String label = generator.getLocaleString(lang, r["key"]!);
            return ChoiceChip(
              materialTapTargetSize: MaterialTapTargetSize.padded,
              label: Text(label.isNotEmpty ? label : val),
              selected: aspectRatioStr == val,
              onSelected: (_) => setState(() => aspectRatioStr = val),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<VerseTextStyleOptions>(
          valueListenable: _textStyleNotifier,
          builder: (context, textStyle, _) {
            final ThemeData theme = Theme.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card.outlined(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Semantics(
                              header: true,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ExcludeSemantics(
                                    child: Icon(
                                      Icons.text_fields,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      generator.getLocaleString(
                                        lang,
                                        "typography_section_title",
                                      ),
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!textStyle.isDefault)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  _updateTextStyle(
                                    const VerseTextStyleOptions(),
                                  );
                                },
                                icon: const ExcludeSemantics(
                                  child: Icon(Icons.restart_alt, size: 16),
                                ),
                                label: Text(
                                  generator.getLocaleString(
                                    lang,
                                    "reset_style_btn",
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          generator.getLocaleString(
                            lang,
                            "style_presets_label",
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _stylePresets.map((entry) {
                            final String label = generator.getLocaleString(
                              lang,
                              entry.key,
                            );
                            final VerseTextStyleOptions preset = entry.value;
                            return ChoiceChip(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              label: Text(
                                label,
                                style: VersePreviewCard.resolveBaseTextStyle(
                                  preset.fontFamily,
                                ),
                              ),
                              selected: textStyle == preset,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                _updateTextStyle(preset);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          generator.getLocaleString(lang, "font_type_label"),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: VerseFontFamily.values.map((family) {
                            final String label = generator.getLocaleString(
                              lang,
                              family.localeKey,
                            );
                            final TextStyle previewStyle =
                                VersePreviewCard.resolveBaseTextStyle(family);
                            return ChoiceChip(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              label: Text(label, style: previewStyle),
                              selected: textStyle.fontFamily == family,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                _updateTextStyle(
                                  textStyle.copyWith(fontFamily: family),
                                );
                              },
                            );
                          }).toList(),
                        ),
                        if (textStyle.fontFamily == VerseFontFamily.cursive)
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: verseController,
                            builder: (context, verseVal, _) {
                              if (verseVal.text.trim().length <= 80) {
                                return const SizedBox.shrink();
                              }
                              return Semantics(
                                liveRegion: true,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 10.0),
                                  child: Card(
                                    margin: EdgeInsets.zero,
                                    color: theme.colorScheme.tertiaryContainer,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0,
                                        vertical: 6.0,
                                      ),
                                      child: Row(
                                        children: [
                                          ExcludeSemantics(
                                            child: Icon(
                                              Icons.visibility_outlined,
                                              size: 20,
                                              color: theme
                                                  .colorScheme
                                                  .onTertiaryContainer,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              generator.getLocaleString(
                                                lang,
                                                "script_legibility_tip",
                                              ),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onTertiaryContainer,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              minimumSize: const Size(0, 48),
                                              foregroundColor: theme
                                                  .colorScheme
                                                  .onTertiaryContainer,
                                            ),
                                            onPressed: () {
                                              HapticFeedback.selectionClick();
                                              _updateTextStyle(
                                                textStyle.copyWith(
                                                  fontFamily:
                                                      VerseFontFamily.lora,
                                                ),
                                              );
                                            },
                                            child: Text(
                                              generator.getLocaleString(
                                                lang,
                                                "script_legibility_fix_btn",
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 12),
                        Text(
                          generator.getLocaleString(lang, "font_format_label"),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              avatar: const ExcludeSemantics(
                                child: Icon(Icons.format_bold, size: 18),
                              ),
                              label: Text(
                                generator.getLocaleString(
                                  lang,
                                  "font_bold_label",
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: textStyle.isBold,
                              onSelected: (selected) {
                                HapticFeedback.selectionClick();
                                _updateTextStyle(
                                  textStyle.copyWith(isBold: selected),
                                );
                              },
                            ),
                            FilterChip(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              avatar: const ExcludeSemantics(
                                child: Icon(Icons.format_italic, size: 18),
                              ),
                              label: Text(
                                generator.getLocaleString(
                                  lang,
                                  "font_italic_label",
                                ),
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              selected: textStyle.isItalic,
                              onSelected: (selected) {
                                HapticFeedback.selectionClick();
                                _updateTextStyle(
                                  textStyle.copyWith(isItalic: selected),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          generator.getLocaleString(lang, "text_align_label"),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Semantics(
                          label: generator.getLocaleString(
                            lang,
                            "text_align_label",
                          ),
                          child: MediaQuery.textScalerOf(context).scale(14) > 20
                              ? Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final entry in const [
                                      (
                                        TextAlign.left,
                                        "align_left",
                                        Icons.format_align_left,
                                      ),
                                      (
                                        TextAlign.center,
                                        "align_center",
                                        Icons.format_align_center,
                                      ),
                                      (
                                        TextAlign.right,
                                        "align_right",
                                        Icons.format_align_right,
                                      ),
                                    ])
                                      ChoiceChip(
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.padded,
                                        avatar: ExcludeSemantics(
                                          child: Icon(entry.$3, size: 18),
                                        ),
                                        label: Text(
                                          generator.getLocaleString(
                                            lang,
                                            entry.$2,
                                          ),
                                        ),
                                        selected:
                                            textStyle.textAlign == entry.$1,
                                        onSelected: (_) {
                                          HapticFeedback.selectionClick();
                                          _updateTextStyle(
                                            textStyle.copyWith(
                                              textAlign: entry.$1,
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                )
                              : SizedBox(
                                  width: double.infinity,
                                  child: SegmentedButton<TextAlign>(
                                    style: const ButtonStyle(
                                      minimumSize: WidgetStatePropertyAll(
                                        Size(0, 48),
                                      ),
                                    ),
                                    segments: [
                                      ButtonSegment<TextAlign>(
                                        value: TextAlign.left,
                                        tooltip: generator.getLocaleString(
                                          lang,
                                          "align_left",
                                        ),
                                        icon: const ExcludeSemantics(
                                          child: Icon(
                                            Icons.format_align_left,
                                            size: 18,
                                          ),
                                        ),
                                        label: Text(
                                          generator.getLocaleString(
                                            lang,
                                            "align_left",
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      ButtonSegment<TextAlign>(
                                        value: TextAlign.center,
                                        tooltip: generator.getLocaleString(
                                          lang,
                                          "align_center",
                                        ),
                                        icon: const ExcludeSemantics(
                                          child: Icon(
                                            Icons.format_align_center,
                                            size: 18,
                                          ),
                                        ),
                                        label: Text(
                                          generator.getLocaleString(
                                            lang,
                                            "align_center",
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      ButtonSegment<TextAlign>(
                                        value: TextAlign.right,
                                        tooltip: generator.getLocaleString(
                                          lang,
                                          "align_right",
                                        ),
                                        icon: const ExcludeSemantics(
                                          child: Icon(
                                            Icons.format_align_right,
                                            size: 18,
                                          ),
                                        ),
                                        label: Text(
                                          generator.getLocaleString(
                                            lang,
                                            "align_right",
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                    selected: {textStyle.textAlign},
                                    onSelectionChanged:
                                        (Set<TextAlign> selection) {
                                          if (selection.isEmpty) return;
                                          HapticFeedback.selectionClick();
                                          _updateTextStyle(
                                            textStyle.copyWith(
                                              textAlign: selection.first,
                                            ),
                                          );
                                        },
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          generator.getLocaleString(lang, "card_accent_label"),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: VerseCardAccent.values.map((accent) {
                            final String label = generator.getLocaleString(
                              lang,
                              accent.localeKey,
                            );
                            return ChoiceChip(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              label: Text(label),
                              selected: textStyle.accent == accent,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                _updateTextStyle(
                                  textStyle.copyWith(accent: accent),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card.outlined(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Row(
                            children: [
                              ExcludeSemantics(
                                child: Icon(
                                  Icons.accessibility_new,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  generator.getLocaleString(
                                    lang,
                                    "readability_section_title",
                                  ),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          generator.getLocaleString(lang, "text_shadow_label"),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: VerseTextShadow.values.map((shadow) {
                            final String label = generator.getLocaleString(
                              lang,
                              shadow.localeKey,
                            );
                            return ChoiceChip(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              label: Text(label),
                              selected: textStyle.shadow == shadow,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                _updateTextStyle(
                                  textStyle.copyWith(shadow: shadow),
                                );
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          generator.getLocaleString(
                            lang,
                            "text_backdrop_label",
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: VerseTextBackdrop.values.map((backdrop) {
                            final String label = generator.getLocaleString(
                              lang,
                              backdrop.localeKey,
                            );
                            return ChoiceChip(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              label: Text(label),
                              selected: textStyle.backdrop == backdrop,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                _updateTextStyle(
                                  textStyle.copyWith(backdrop: backdrop),
                                );
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "${generator.getLocaleString(lang, "line_spacing_label")}: ${textStyle.lineHeight.toStringAsFixed(2)}x",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if ((textStyle.lineHeight -
                                        VerseTextStyleOptions
                                            .defaultLineHeight)
                                    .abs() >
                                0.01)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  _updateTextStyle(
                                    textStyle.copyWith(
                                      lineHeight: VerseTextStyleOptions
                                          .defaultLineHeight,
                                    ),
                                  );
                                },
                                icon: const ExcludeSemantics(
                                  child: Icon(Icons.restart_alt, size: 16),
                                ),
                                label: Text(
                                  generator.getLocaleString(
                                    lang,
                                    "reset_line_spacing_btn",
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              tooltip: generator.getLocaleString(
                                lang,
                                "decrease_line_spacing_tooltip",
                              ),
                              onPressed: textStyle.lineHeight > 1.01
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      final double next = double.parse(
                                        (textStyle.lineHeight - 0.05)
                                            .clamp(1.0, 2.0)
                                            .toStringAsFixed(2),
                                      );
                                      _updateTextStyle(
                                        textStyle.copyWith(lineHeight: next),
                                      );
                                    }
                                  : null,
                              icon: const Icon(Icons.remove),
                            ),
                            Expanded(
                              child: Slider(
                                value: textStyle.lineHeight,
                                min: 1.0,
                                max: 2.0,
                                divisions: 20,
                                label:
                                    "${textStyle.lineHeight.toStringAsFixed(2)}x",
                                semanticFormatterCallback: (v) =>
                                    "${generator.getLocaleString(lang, "line_spacing_label")}: ${v.toStringAsFixed(2)}x",
                                onChanged: (v) {
                                  _updateTextStyle(
                                    textStyle.copyWith(
                                      lineHeight: double.parse(
                                        v.toStringAsFixed(2),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              tooltip: generator.getLocaleString(
                                lang,
                                "increase_line_spacing_tooltip",
                              ),
                              onPressed: textStyle.lineHeight < 1.99
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      final double next = double.parse(
                                        (textStyle.lineHeight + 0.05)
                                            .clamp(1.0, 2.0)
                                            .toStringAsFixed(2),
                                      );
                                      _updateTextStyle(
                                        textStyle.copyWith(lineHeight: next),
                                      );
                                    }
                                  : null,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              "${generator.getLocaleString(lang, "letter_spacing_label")}: ${textStyle.letterSpacing.toStringAsFixed(1)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if ((textStyle.letterSpacing -
                                        VerseTextStyleOptions
                                            .defaultLetterSpacing)
                                    .abs() >
                                0.05)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  _updateTextStyle(
                                    textStyle.copyWith(
                                      letterSpacing: VerseTextStyleOptions
                                          .defaultLetterSpacing,
                                    ),
                                  );
                                },
                                icon: const ExcludeSemantics(
                                  child: Icon(Icons.restart_alt, size: 16),
                                ),
                                label: Text(
                                  generator.getLocaleString(
                                    lang,
                                    "reset_letter_spacing_btn",
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              tooltip: generator.getLocaleString(
                                lang,
                                "decrease_letter_spacing_tooltip",
                              ),
                              onPressed: textStyle.letterSpacing > 0.05
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      final double next = double.parse(
                                        (textStyle.letterSpacing - 0.1)
                                            .clamp(0.0, 2.0)
                                            .toStringAsFixed(2),
                                      );
                                      _updateTextStyle(
                                        textStyle.copyWith(letterSpacing: next),
                                      );
                                    }
                                  : null,
                              icon: const Icon(Icons.remove),
                            ),
                            Expanded(
                              child: Slider(
                                value: textStyle.letterSpacing.clamp(0.0, 2.0),
                                min: 0.0,
                                max: 2.0,
                                divisions: 20,
                                label: textStyle.letterSpacing.toStringAsFixed(
                                  1,
                                ),
                                semanticFormatterCallback: (v) =>
                                    "${generator.getLocaleString(lang, "letter_spacing_label")}: ${v.toStringAsFixed(1)}",
                                onChanged: (v) {
                                  _updateTextStyle(
                                    textStyle.copyWith(
                                      letterSpacing: double.parse(
                                        v.toStringAsFixed(2),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              tooltip: generator.getLocaleString(
                                lang,
                                "increase_letter_spacing_tooltip",
                              ),
                              onPressed: textStyle.letterSpacing < 1.95
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      final double next = double.parse(
                                        (textStyle.letterSpacing + 0.1)
                                            .clamp(0.0, 2.0)
                                            .toStringAsFixed(2),
                                      );
                                      _updateTextStyle(
                                        textStyle.copyWith(letterSpacing: next),
                                      );
                                    }
                                  : null,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            generator.getLocaleString(lang, "font_color_label"),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<Color>(
          valueListenable: _fontColorNotifier,
          builder: (context, currentColor, _) {
            final String activeColorName = ColorAccessibility.describeColorName(
              currentColor,
              lang,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in _presetColors)
                      Builder(
                        builder: (context) {
                          final Color preset = entry.key;
                          final bool isSelected =
                              currentColor.toARGB32() == preset.toARGB32();
                          final String colorName = generator.getLocaleString(
                            lang,
                            entry.value,
                          );
                          return ChoiceChip(
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                            avatar: ExcludeSemantics(
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: preset,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            label: Text(colorName),
                            selected: isSelected,
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              _fontColorNotifier.value = preset;
                            },
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => _applySuggestedSafeColor(lang),
                      icon: const ExcludeSemantics(
                        child: Icon(Icons.auto_fix_high, size: 18),
                      ),
                      label: Text(
                        generator.getLocaleString(
                          lang,
                          "suggest_safe_color_btn",
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: currentColor,
                        foregroundColor:
                            VersePreviewCard.computeWcagContrastRatio(
                                  currentColor.computeLuminance(),
                                  0.0,
                                ) >=
                                VersePreviewCard.computeWcagContrastRatio(
                                  currentColor.computeLuminance(),
                                  1.0,
                                )
                            ? Colors.black
                            : Colors.white,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                          width: 1.5,
                        ),
                      ),
                      onPressed: () async {
                        final Color previousColor = currentColor;
                        final bool? confirmed = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text(
                                generator.getLocaleString(
                                  lang,
                                  "pick_color_title",
                                ),
                              ),
                              content: SingleChildScrollView(
                                child: ValueListenableBuilder<Color>(
                                  valueListenable: _fontColorNotifier,
                                  builder: (context, pickedColor, _) {
                                    final String liveName =
                                        ColorAccessibility.describeColorName(
                                          pickedColor,
                                          lang,
                                        );
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Semantics(
                                          liveRegion: true,
                                          child: Text(
                                            generator
                                                .getLocaleString(
                                                  lang,
                                                  "selected_color_name_label",
                                                )
                                                .replaceAll(
                                                  "{color}",
                                                  liveName,
                                                ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        ColorPicker(
                                          pickerColor: pickedColor,
                                          enableAlpha: false,
                                          hexInputBar: true,
                                          labelTypes: const [
                                            ColorLabelType.rgb,
                                            ColorLabelType.hex,
                                          ],
                                          onColorChanged: (c) =>
                                              _fontColorNotifier.value = c,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              actions: <Widget>[
                                TextButton(
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, 48),
                                  ),
                                  onPressed: () {
                                    _fontColorNotifier.value = previousColor;
                                    Navigator.of(context).pop(false);
                                  },
                                  child: Text(
                                    generator.getLocaleString(
                                      lang,
                                      "gemini_cancel_btn",
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(0, 48),
                                  ),
                                  child: Text(
                                    generator.getLocaleString(
                                      lang,
                                      "got_it_btn",
                                    ),
                                  ),
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                ),
                              ],
                            );
                          },
                        );
                        if (confirmed != true) {
                          _fontColorNotifier.value = previousColor;
                        }
                      },
                      icon: const ExcludeSemantics(
                        child: Icon(Icons.color_lens, size: 18),
                      ),
                      label: Text(
                        "${generator.getLocaleString(lang, "select_color_btn")} ($activeColorName)",
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        _buildContrastWarningCard(lang, tabIndex: 2),
        const SizedBox(height: 12),
        ValueListenableBuilder<double>(
          valueListenable: _fontSizeNotifier,
          builder: (context, sizeValue, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "${generator.getLocaleString(lang, "font_size_label")}: ${sizeValue.round()}",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (sizeValue.round() != 22)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () => _fontSizeNotifier.value = 22.0,
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: Text(
                          generator.getLocaleString(lang, "reset_font_size_btn"),
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      tooltip: generator.getLocaleString(
                        lang,
                        "decrease_font_size_tooltip",
                      ),
                      onPressed: sizeValue > 20
                          ? () {
                              HapticFeedback.selectionClick();
                              _fontSizeNotifier.value =
                                  (sizeValue - 2).clamp(20.0, 120.0);
                            }
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Expanded(
                      child: Slider(
                        value: sizeValue,
                        min: 20,
                        max: 120,
                        divisions: 100,
                        label: sizeValue.round().toString(),
                        semanticFormatterCallback: (v) =>
                            "${generator.getLocaleString(lang, "font_size_label")}: ${v.round()}",
                        onChanged: (v) => _fontSizeNotifier.value = v,
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      tooltip: generator.getLocaleString(
                        lang,
                        "increase_font_size_tooltip",
                      ),
                      onPressed: sizeValue < 120
                          ? () {
                              HapticFeedback.selectionClick();
                              _fontSizeNotifier.value =
                                  (sizeValue + 2).clamp(20.0, 120.0);
                            }
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        ValueListenableBuilder<double>(
          valueListenable: _yOffsetNotifier,
          builder: (context, offsetValue, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "${generator.getLocaleString(lang, "y_offset_label")}: ${offsetValue.round()}",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (offsetValue.round() != 0)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () => _yOffsetNotifier.value = 0.0,
                        icon: const Icon(Icons.vertical_align_center, size: 16),
                        label: Text(
                          generator.getLocaleString(lang, "reset_position_btn"),
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      tooltip: generator.getLocaleString(
                        lang,
                        "move_text_up_tooltip",
                      ),
                      onPressed: offsetValue > -400
                          ? () {
                              HapticFeedback.selectionClick();
                              _yOffsetNotifier.value =
                                  (offsetValue - 20).clamp(-400.0, 400.0);
                            }
                          : null,
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    Expanded(
                      child: Slider(
                        value: offsetValue,
                        min: -400,
                        max: 400,
                        divisions: 800,
                        label: offsetValue.round().toString(),
                        semanticFormatterCallback: (v) =>
                            "${generator.getLocaleString(lang, "y_offset_label")}: ${v.round()}",
                        onChanged: (v) => _yOffsetNotifier.value = v,
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      tooltip: generator.getLocaleString(
                        lang,
                        "move_text_down_tooltip",
                      ),
                      onPressed: offsetValue < 400
                          ? () {
                              HapticFeedback.selectionClick();
                              _yOffsetNotifier.value =
                                  (offsetValue + 20).clamp(-400.0, 400.0);
                            }
                          : null,
                      icon: const Icon(Icons.arrow_downward),
                    ),
                  ],
                ),
              ],
            );
          },
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
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: generateAudio,
                  onChanged: (bool? v) {
                    if (v != null) {
                      setState(() => generateAudio = v);
                    }
                  },
                  title: Text(
                    generator.getLocaleString(lang, "audio_label"),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      generator.getLocaleString(lang, "audio_speed_label"),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    for (final double speed in _ttsSpeedOptions)
                      ChoiceChip(
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        label: Text(
                          "${speed == speed.roundToDouble() ? speed.toStringAsFixed(0) : speed}x",
                        ),
                        selected: (_ttsSpeedMultiplier - speed).abs() < 0.01,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _ttsSpeedMultiplier = speed);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(generator.getLocaleString(lang, "gender_label")),
                    Semantics(
                      label: generator.getLocaleString(lang, "gender_label"),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: DropdownButton<String>(
                          itemHeight: null,
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
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: verseController,
                      builder: (context, value, child) {
                        return OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
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
                AnimatedBuilder(
                  animation: _previewListenable,
                  builder: (context, _) {
                    // ⚡ Bolt: Skip spoken-script regex & SelectableText layout on keystrokes when Audio tab is inactive
                    if (_selectedTabIndex != 3) {
                      return const SizedBox.shrink();
                    }
                    final String verseText = verseController.text.trim();
                    if (verseText.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final String transcript = TtsService.buildSpokenScript(
                      verse: verseText,
                      reference: referenceController.text.trim(),
                      lang: getAudioLangKey(),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                          color: isPlayingAudioPreview
                              ? Theme.of(
                                  context,
                                ).colorScheme.primaryContainer.withAlpha(140)
                              : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha(90),
                          borderRadius: BorderRadius.circular(8),
                          border: isPlayingAudioPreview
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              liveRegion: isPlayingAudioPreview,
                              child: MergeSemantics(
                                child: Row(
                                  children: [
                                    ExcludeSemantics(
                                      child: Icon(
                                        isPlayingAudioPreview
                                            ? Icons.graphic_eq
                                            : Icons.subtitles_outlined,
                                        size: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        generator.getLocaleString(
                                          lang,
                                          isPlayingAudioPreview
                                              ? "audio_playing_caption"
                                              : "audio_transcript_label",
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Builder(
                              builder: (context) {
                                final (int, int)? range = _spokenWordRange;
                                final TextStyle? baseTranscriptStyle = Theme.of(
                                  context,
                                ).textTheme.bodySmall;
                                if (isPlayingAudioPreview &&
                                    range != null &&
                                    range.$1 >= 0 &&
                                    range.$2 > range.$1 &&
                                    range.$2 <= transcript.length) {
                                  final ColorScheme cs = Theme.of(
                                    context,
                                  ).colorScheme;
                                  return SelectableText.rich(
                                    TextSpan(
                                      style: baseTranscriptStyle,
                                      children: [
                                        TextSpan(
                                          text: transcript.substring(
                                            0,
                                            range.$1,
                                          ),
                                        ),
                                        TextSpan(
                                          text: transcript.substring(
                                            range.$1,
                                            range.$2,
                                          ),
                                          style: baseTranscriptStyle?.copyWith(
                                            backgroundColor:
                                                cs.primaryContainer,
                                            color: cs.onPrimaryContainer,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        TextSpan(
                                          text: transcript.substring(range.$2),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return SelectableText(
                                  transcript,
                                  style: baseTranscriptStyle,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _previewListenable,
          builder: (context, _) {
            if (_selectedTabIndex != 3) {
              return const SizedBox.shrink();
            }
            final String verseText = verseController.text.trim();
            final String refText = referenceController.text.trim();
            if (verseText.isEmpty || refText.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: MergeSemantics(
                        child: Row(
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                Icons.accessibility_new,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                generator.getLocaleString(
                                  lang,
                                  "text_empty_state",
                                ),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            final String description =
                _activeImageDescription ??
                generator.getLocaleString(
                  lang,
                  "default_description",
                );
            final String liveAltText = generator.getLocaleString(
              lang,
              "alt_text_template",
              kwargs: {
                "description": description,
                "verse": verseText,
                "reference": refText,
              },
            );
            final String liveCaption = generator.getLocaleString(
              lang,
              "caption_template",
              kwargs: {"verse": verseText, "reference": refText},
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (liveAltText.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _imageDescriptionController,
                    builder: (context, value, child) {
                      return TextField(
                        controller: _imageDescriptionController,
                        focusNode: _imageDescriptionFocusNode,
                        // 🛡️ Sentinel: Bound custom image description input length to prevent oversized text payloads
                        maxLength: 500,
                        maxLines: 2,
                        decoration: InputDecoration(
                          counterText: '',
                          alignLabelWithHint: true,
                          labelText: generator.getLocaleString(
                            lang,
                            "custom_image_desc_label",
                          ),
                          hintText: generator.getLocaleString(
                            lang,
                            "custom_image_desc_hint",
                          ),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          suffixIcon: value.text.isNotEmpty
                              ? IconButton(
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  icon: const Icon(Icons.clear),
                                  tooltip: generator.getLocaleString(
                                    lang,
                                    "clear_image_desc_tooltip",
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _onDeviceImageDescription = null;
                                      _imageDescriptionController.clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    header: true,
                    child: Text(
                      generator.getLocaleString(lang, "alt_text_label"),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(liveAltText),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () =>
                            _copyToClipboard(liveAltText, fieldKey: "alt"),
                        icon: Icon(
                          _copiedField == "alt" ? Icons.check : Icons.copy,
                          size: 16,
                          color: _copiedField == "alt"
                              ? _successColor(context)
                              : null,
                        ),
                        label: Text(
                          generator.getLocaleString(lang, "copy_alt_text_btn"),
                        ),
                      ),
                      if (_geminiNanoAvailability.isCompatible &&
                          _geminiNanoEnabled)
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: _isDescribingImage
                              ? null
                              : _describeCurrentBackgroundWithGeminiNano,
                          icon: _isDescribingImage
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome, size: 18),
                          label: Text(
                            generator.getLocaleString(
                              lang,
                              "gemini_nano_describe_btn",
                            ),
                          ),
                        ),
                      if (_geminiNanoAvailability.isCompatible &&
                          _geminiNanoEnabled &&
                          _onDeviceImageDescription != null)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () {
                            setState(() {
                              _onDeviceImageDescription = null;
                              _imageDescriptionController.clear();
                            });
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: Text(
                            generator.getLocaleString(
                              lang,
                              "gemini_nano_clear_btn",
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (liveCaption.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    header: true,
                    child: Text(
                      generator.getLocaleString(lang, "caption_label"),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(liveCaption),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () =>
                        _copyToClipboard(liveCaption, fieldKey: "caption"),
                    icon: Icon(
                      _copiedField == "caption" ? Icons.check : Icons.copy,
                      size: 16,
                      color: _copiedField == "caption"
                          ? _successColor(context)
                          : null,
                    ),
                    label: Text(
                      generator.getLocaleString(lang, "copy_caption_btn"),
                    ),
                  ),
                ],
                if (_geminiHandoffEnabled) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(
                      generator.getLocaleString(
                        lang,
                        "gemini_handoff_section_title",
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () => _shareToGemini(
                          GeminiHandoffTask.devotionalCaption,
                        ),
                        icon: const Icon(Icons.share, size: 18),
                        label: Text(
                          generator.getLocaleString(
                            lang,
                            "gemini_handoff_caption_btn",
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () => _copyAndOpenGemini(
                          GeminiHandoffTask.devotionalCaption,
                        ),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(
                          generator.getLocaleString(
                            lang,
                            "gemini_handoff_open_btn",
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
        _buildInclusivityScorecard(lang),
        _buildStepNavigationRow(lang, 3),
      ],
    );
  }

  Widget _buildInclusivityScorecard(String lang) {
    return AnimatedBuilder(
      animation: _scorecardListenable,
      builder: (context, _) {
        // ⚡ Bolt: Skip scorecard WCAG/CVD contrast checks & chip rebuilds when Audio/Text tab (3) is inactive
        if (_selectedTabIndex != 3) {
          return const SizedBox.shrink();
        }
        final String verseText = verseController.text.trim();
        final String refText = referenceController.text.trim();
        final bool hasVerse = verseText.isNotEmpty && refText.isNotEmpty;
        // ⚡ Bolt: Reuse effectiveBgLum for normalRatio and short-circuit CVD check when normalRatio < 4.5
        final Color currentFontColor = _fontColorNotifier.value;
        final double effectiveBgLum = _effectiveBackgroundLuminance();
        final double normalRatio = VersePreviewCard.computeWcagContrastRatio(
          currentFontColor.computeLuminance(),
          effectiveBgLum,
        );
        final bool contrastOk =
            normalRatio >= 4.5 &&
            ColorAccessibility.worstCaseCvdContrast(
                  textColor: currentFontColor,
                  backgroundColor: _effectiveBackgroundColor(effectiveBgLum),
                ).minRatio >=
                4.5;
        final bool altTextOk =
            hasVerse &&
            (customImagePath == null || _activeImageDescription != null);
        final VerseTextStyleOptions style = _textStyleNotifier.value;
        final bool typographyOk =
            _fontSizeNotifier.value >= 22.0 &&
            !(style.fontFamily == VerseFontFamily.cursive &&
                verseText.length > 80);
        final bool captionsOk = hasVerse;

        final int score =
            (contrastOk ? 1 : 0) +
            (altTextOk ? 1 : 0) +
            (typographyOk ? 1 : 0) +
            (captionsOk ? 1 : 0);

        final ThemeData theme = Theme.of(context);
        final Color successColor = _successColor(context);
        final String headerText = generator
            .getLocaleString(lang, "inclusivity_score_title")
            .replaceAll("{score}", "$score")
            .replaceAll("{total}", "4");
        final String passedStatus = generator.getLocaleString(
          lang,
          "inclusivity_status_passed",
        );
        final String needsAttentionStatus = generator.getLocaleString(
          lang,
          "inclusivity_status_needs_attention",
        );
        final String fixHint = generator.getLocaleString(
          lang,
          "inclusivity_fix_hint",
        );

        Widget buildCheckChip({
          required String label,
          required bool ok,
          VoidCallback? onFix,
        }) {
          final String semanticText =
              "$label: ${ok ? passedStatus : needsAttentionStatus}";
          if (ok) {
            return Semantics(
              container: true,
              label: semanticText,
              child: ExcludeSemantics(
                child: Chip(
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  avatar: Icon(
                    Icons.check_circle,
                    size: 18,
                    color: successColor,
                  ),
                  label: Text(label),
                ),
              ),
            );
          }
          return Semantics(
            button: true,
            label: semanticText,
            hint: fixHint,
            child: ActionChip(
              materialTapTargetSize: MaterialTapTargetSize.padded,
              avatar: ExcludeSemantics(
                child: Icon(
                  Icons.radio_button_unchecked,
                  size: 18,
                  color: theme.colorScheme.tertiary,
                ),
              ),
              label: ExcludeSemantics(child: Text(label)),
              onPressed: onFix,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Card.outlined(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            score == 4
                                ? Icons.verified_user
                                : Icons.accessibility_new,
                            size: 18,
                            color: score == 4
                                ? successColor
                                : theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            headerText,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      buildCheckChip(
                        label: generator.getLocaleString(
                          lang,
                          "inclusivity_check_contrast",
                        ),
                        ok: contrastOk,
                        onFix: () => _selectTab(2),
                      ),
                      buildCheckChip(
                        label: generator.getLocaleString(
                          lang,
                          "inclusivity_check_alt_text",
                        ),
                        ok: altTextOk,
                        onFix: () {
                          if (!hasVerse) {
                            _selectTab(0);
                            return;
                          }
                          _selectTab(3);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            final BuildContext? targetCtx =
                                _imageDescriptionFocusNode.context;
                            if (targetCtx != null) {
                              Scrollable.ensureVisible(
                                targetCtx,
                                duration:
                                    MediaQuery.of(context).disableAnimations
                                    ? Duration.zero
                                    : const Duration(milliseconds: 220),
                                alignment: 0.25,
                              );
                            }
                            _imageDescriptionFocusNode.requestFocus();
                          });
                        },
                      ),
                      buildCheckChip(
                        label: generator.getLocaleString(
                          lang,
                          "inclusivity_check_typography",
                        ),
                        ok: typographyOk,
                        onFix: () => _selectTab(2),
                      ),
                      buildCheckChip(
                        label: generator.getLocaleString(
                          lang,
                          "inclusivity_check_captions",
                        ),
                        ok: captionsOk,
                        onFix: () => _selectTab(0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          ExcludeSemantics(
            child: LinearProgressIndicator(
              value: (_selectedTabIndex + 1) / _stepTabKeys.length,
              minHeight: 4,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withAlpha(60),
            child: ExcludeSemantics(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
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
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (hasBack)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
              ),
              onPressed: () => _selectTab(stepIndex - 1),
              icon: const ExcludeSemantics(
                child: Icon(Icons.arrow_back, size: 18),
              ),
              label: Text(generator.getLocaleString(lang, "step_back_btn")),
            ),
          if (hasNext)
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
              ),
              onPressed: () => _selectTab(stepIndex + 1),
              icon: const ExcludeSemantics(
                child: Icon(Icons.arrow_forward, size: 18),
              ),
              iconAlignment: IconAlignment.end,
              label: Text(nextLabel),
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
            if (isPlayingAudioPreview)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.graphic_eq,
                          size: 18,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          generator.getLocaleString(
                            lang,
                            "audio_playing_banner",
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                        onPressed: _toggleAudioPreview,
                        icon: const ExcludeSemantics(
                          child: Icon(Icons.stop, size: 18),
                        ),
                        label: Text(
                          generator.getLocaleString(lang, "stop_audio_btn"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: MergeSemantics(
                          child: Row(
                            children: [
                              ExcludeSemantics(
                                child: Icon(
                                  isError
                                      ? Icons.error
                                      : (isSuccess
                                            ? Icons.check_circle
                                            : Icons.info),
                                  size: 18,
                                  color: isError
                                      ? _errorColor(context)
                                      : (isSuccess
                                            ? _successColor(context)
                                            : Theme.of(
                                                context,
                                              ).colorScheme.primary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  statusMessage,
                                  maxLines: 6,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: isError
                                            ? _errorColor(context)
                                            : (isSuccess
                                                  ? _successColor(context)
                                                  : Theme.of(
                                                      context,
                                                    ).colorScheme.primary),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: generator.getLocaleString(
                        lang,
                        "dismiss_status_tooltip",
                      ),
                      onPressed: () {
                        setState(() {
                          statusMessage = "";
                        });
                      },
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _previewListenable,
                builder: (context, child) {
                  return FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
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
      final String loadingLabel = generator.getLocaleString(
        getLangKey(),
        "loading_app_semantics",
      );
      return Scaffold(
        body: Center(
          child: Semantics(
            liveRegion: true,
            child: CircularProgressIndicator(
              semanticsLabel: loadingLabel.isEmpty
                  ? "Loading Inclusive Bible Generator"
                  : loadingLabel,
            ),
          ),
        ),
      );
    }

    final String lang = getLangKey();

    final Widget previewWidget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
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
                fontColor: _fontColorNotifier.value,
                fontSize: _fontSizeNotifier.value,
                yOffset: _yOffsetNotifier.value,
                backgroundDim: _backgroundDimNotifier.value,
                textStyleOptions: _textStyleNotifier.value,
                fontColorListenable: _fontColorNotifier,
                fontSizeListenable: _fontSizeNotifier,
                yOffsetListenable: _yOffsetNotifier,
                backgroundDimListenable: _backgroundDimNotifier,
                textStyleListenable: _textStyleNotifier,
                onYOffsetChanged: (updated) => _yOffsetNotifier.value = updated,
                lang: lang,
                bibleLang: bibleLang,
                generator: generator,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ExcludeSemantics(
                child: Text(
                  generator.getLocaleString(lang, "drag_hint"),
                  style: Theme.of(context).textTheme.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.visibility_outlined, size: 20),
              tooltip: generator.getLocaleString(
                lang,
                "expand_preview_tooltip",
              ),
              onPressed: () => _showFullScreenPreview(lang),
            ),
          ],
        ),
      ],
    );

    final Widget tabNavigation = NavigationBar(
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
        ExcludeFocus(excluding: _selectedTabIndex != 0, child: _buildVerseTab(lang)),
        ExcludeFocus(excluding: _selectedTabIndex != 1, child: _buildBackgroundTab(lang)),
        ExcludeFocus(excluding: _selectedTabIndex != 2, child: _buildStyleTab(lang)),
        ExcludeFocus(excluding: _selectedTabIndex != 3, child: _buildAudioAndTextTab(lang)),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Text(
          generator.getLocaleString(lang, "title"),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        actions: [
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.info_outline),
            tooltip: generator.getLocaleString(lang, "about_tooltip"),
            onPressed: _showAboutDialog,
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.auto_awesome),
            tooltip: generator.getLocaleString(
              lang,
              "advanced_features_tooltip",
            ),
            onPressed: _showAdvancedFeaturesDialog,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Semantics(
              label:
                  "${generator.getLocaleString(lang, "app_language_label")}: $currentLang",
              child: Container(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 76),
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.language,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isDense: true,
                        itemHeight: null,
                        iconSize: 18,
                        value: currentLang,
                        selectedItemBuilder: (BuildContext context) {
                          return languages
                              .map<Widget>(
                                (String value) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _shortLanguageCode(value),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              )
                              .toList();
                        },
                        onChanged: (String? newValue) {
                          if (newValue == null) return;
                          final bool langChanged = newValue != currentLang;
                          setState(() {
                            currentLang = newValue;
                            if (langChanged &&
                                _onDeviceImageDescription != null) {
                              if (_imageDescriptionController.text.trim() ==
                                  _onDeviceImageDescription!.trim()) {
                                _imageDescriptionController.clear();
                              }
                              _onDeviceImageDescription = null;
                            }
                          });
                          widget.onLocaleChanged?.call(
                            resolveLocaleForAppLanguage(newValue),
                          );
                          _switchBibleLanguage(getLangKey().substring(0, 2));
                        },
                        items: languages.map<DropdownMenuItem<String>>((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(lang),
      body: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool useSideBySide =
                constraints.maxWidth > 800 ||
                (constraints.maxWidth > constraints.maxHeight &&
                    constraints.maxHeight < 520);
            if (useSideBySide) {
              final Widget leftPane = constraints.maxHeight < 280
                  ? SingleChildScrollView(
                      controller: _workspaceScrollController,
                      child: Column(
                        children: [
                          tabNavigation,
                          _buildStepProgressHeader(lang),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: tabbedWorkspace,
                          ),
                        ],
                      ),
                    )
                  : Column(
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
                    );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: leftPane),
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
                      maxHeight: (constraints.maxHeight * 0.34).clamp(
                        130.0,
                        270.0,
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
      ),
    );
  }
}
