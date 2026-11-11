import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
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
  late final Generator generator;
  late final GeminiService geminiService;
  late final TtsService ttsService;
  late final MediaExportService mediaExportService;
  final GlobalKey _globalKey = GlobalKey();

  String currentLang = "Português (Brasil)";
  final List<String> languages = const [
    "Português (Brasil)",
    "English (US/UK)",
    "Español (España)",
  ];

  List<String> bibleVersions = ["-"];
  String selectedBibleVersion = "-";
  Map<String, String> bibleVersionsMap = {};

  final TextEditingController referenceController = TextEditingController();
  final TextEditingController verseController = TextEditingController();
  final TextEditingController geminiPromptController = TextEditingController();

  String selectedBackground = "default.png";
  List<String> backgrounds = ["default.png"];
  String? customImagePath;

  String? geminiAccessToken;
  String? geminiUserEmail;
  String selectedGeminiStyle = GeminiService.styleKeys.first;
  bool isGeneratingGeminiBg = false;
  bool isGeminiBackground = false;

  Color fontColor = Colors.white;
  double fontSize = 60.0;
  String aspectRatioStr = "1:1";
  double yOffset = 0.0;

  bool generateAudio = false;
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
    referenceController.dispose();
    verseController.dispose();
    geminiPromptController.dispose();
    ttsService.stop();
    super.dispose();
  }

  Future<void> _initApp() async {
    await generator.loadLocales();
    geminiAccessToken = await geminiService.signInSilently();
    geminiUserEmail = geminiService.userEmail;
    await _loadBackgrounds();
    await _loadBibleVersions();
    setState(() {
      isLoading = false;
    });
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

  Future<void> _loadBibleVersions() async {
    setState(() {
      _updateStatus("Loading Bible versions...");
    });
    String langCode = "pt";
    if (getLangKey() == "en") {
      langCode = "en";
    } else if (getLangKey() == "es") {
      langCode = "es";
    }

    final versions = await GetBibleAPI.getVersions(lang: langCode);
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
      lang: getLangKey(),
    );
    if (content != null) {
      setState(() {
        isFetching = false;
        verseController.text = content;
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

  Future<bool> _triggerGoogleSignIn() async {
    final String lang = getLangKey();
    final String? token = await geminiService.signInWithGoogle();
    if (token != null && token.isNotEmpty) {
      setState(() {
        geminiAccessToken = token;
        geminiUserEmail = geminiService.userEmail;
        _updateStatus(
          generator.getLocaleString(lang, "gemini_auth_success_msg"),
          forceSuccess: true,
        );
      });
      return true;
    } else {
      setState(() {
        _updateStatus(
          generator.getLocaleString(lang, "gemini_auth_error_msg"),
          forceError: true,
        );
      });
      return false;
    }
  }

  Future<bool> _showGeminiAuthDialog() async {
    final String lang = getLangKey();
    final bool isSignedIn =
        geminiAccessToken != null && geminiAccessToken!.isNotEmpty;

    final bool? connected = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return GeminiAuthDialog(
          lang: lang,
          generator: generator,
          userEmail: geminiUserEmail,
          isSignedIn: isSignedIn,
          onSignIn: _triggerGoogleSignIn,
          onSignOut: () async {
            await geminiService.signOut();
            setState(() {
              geminiAccessToken = null;
              geminiUserEmail = null;
              _updateStatus(
                generator.getLocaleString(lang, "gemini_signed_out_msg"),
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

    if (geminiAccessToken == null || geminiAccessToken!.isEmpty) {
      final bool signedIn = await _triggerGoogleSignIn();
      if (!signedIn ||
          geminiAccessToken == null ||
          geminiAccessToken!.isEmpty) {
        return;
      }
    } else {
      final String? refreshedToken = await geminiService.getAccessToken();
      if (refreshedToken != null && refreshedToken.isNotEmpty) {
        geminiAccessToken = refreshedToken;
      }
    }

    setState(() {
      isGeneratingGeminiBg = true;
      _updateStatus(generator.getLocaleString(lang, "gemini_generating_msg"));
    });

    final Uint8List? imageBytes = await geminiService.generateBackgroundImage(
      accessToken: geminiAccessToken!,
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
      setState(() {
        isGeneratingGeminiBg = false;
        _updateStatus(
          generator.getLocaleString(lang, "gemini_bg_error_msg"),
          forceError: true,
        );
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
        lang: lang,
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

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          generator.getLocaleString(getLangKey(), "copy_success_msg"),
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
        geminiAccessToken != null && geminiAccessToken!.isNotEmpty;

    final Widget previewWidget = VersePreviewCard(
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
      lang: lang,
      generator: generator,
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
              isGeminiConnected ? Icons.account_circle : Icons.login,
            ),
            onPressed: _showGeminiAuthDialog,
          ),
          DropdownButton<String>(
            value: currentLang,
            onChanged: (String? newValue) {
              setState(() {
                currentLang = newValue!;
                _loadBibleVersions();
              });
            },
            items: languages.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final Widget formContent = Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(generator.getLocaleString(lang, "instructions")),
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Text(
                      generator.getLocaleString(lang, "bible_version_label"),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: selectedBibleVersion,
                      items: bibleVersions
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => selectedBibleVersion = v!),
                    ),
                    const SizedBox(width: 10),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: referenceController,
                      builder: (context, value, child) {
                        return ElevatedButton.icon(
                          onPressed:
                              isFetching ||
                                  selectedBibleVersion == "-" ||
                                  value.text.trim().isEmpty
                              ? null
                              : _fetchVerse,
                          icon: isFetching
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download),
                          label: Text(
                            generator.getLocaleString(lang, "fetch_verse_btn"),
                          ),
                        );
                      },
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
                        labelText: generator.getLocaleString(
                          lang,
                          "reference_label",
                        ),
                        suffixIcon: value.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                tooltip: generator.getLocaleString(
                                  lang,
                                  "clear_btn",
                                ),
                                onPressed: referenceController.clear,
                              )
                            : null,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: verseController,
                  builder: (context, value, child) {
                    return TextField(
                      controller: verseController,
                      maxLength: 2000,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        alignLabelWithHint: true,
                        labelText: generator.getLocaleString(
                          lang,
                          "verse_label",
                        ),
                        suffixIcon: value.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                tooltip: generator.getLocaleString(
                                  lang,
                                  "clear_btn",
                                ),
                                onPressed: verseController.clear,
                              )
                            : null,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Text(generator.getLocaleString(lang, "background_label")),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: selectedBackground,
                      items: backgrounds
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        selectedBackground = v!;
                        customImagePath = null;
                        isGeminiBackground = false;
                      }),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _selectCustomImage,
                      icon: const Icon(Icons.image),
                      label: Text(
                        generator.getLocaleString(lang, "custom_image_btn"),
                      ),
                    ),
                  ],
                ),
                GeminiBackgroundCard(
                  lang: lang,
                  generator: generator,
                  isConnected: isGeminiConnected,
                  userEmail: geminiUserEmail,
                  selectedStyle: selectedGeminiStyle,
                  onStyleChanged: (v) =>
                      setState(() => selectedGeminiStyle = v),
                  promptController: geminiPromptController,
                  verseController: verseController,
                  isGenerating: isGeneratingGeminiBg,
                  onConnectPressed: isGeminiConnected
                      ? _showGeminiAuthDialog
                      : _triggerGoogleSignIn,
                  onGeneratePressed: _generateGeminiBackground,
                ),
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Text(generator.getLocaleString(lang, "font_color_label")),
                    const SizedBox(width: 10),
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
                                generator.getLocaleString(
                                  lang,
                                  "pick_color_title",
                                ),
                              ),
                              content: SingleChildScrollView(
                                child: ColorPicker(
                                  pickerColor: fontColor,
                                  onColorChanged: (c) =>
                                      setState(() => fontColor = c),
                                ),
                              ),
                              actions: <Widget>[
                                ElevatedButton(
                                  child: Text(
                                    generator.getLocaleString(
                                      lang,
                                      "got_it_btn",
                                    ),
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.color_lens),
                      label: Text(
                        generator.getLocaleString(lang, "select_color_btn"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "${generator.getLocaleString(lang, "font_size_label")}: ${fontSize.round()}",
                ),
                Slider(
                  value: fontSize,
                  min: 20,
                  max: 120,
                  divisions: 100,
                  label: fontSize.round().toString(),
                  onChanged: (v) => setState(() => fontSize = v),
                ),
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Text(generator.getLocaleString(lang, "aspect_ratio_label")),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: aspectRatioStr,
                      items: ["1:1", "3:4", "4:3"].map((v) {
                        String labelKey = "ratio_square";
                        if (v == "3:4") {
                          labelKey = "ratio_portrait";
                        } else if (v == "4:3") {
                          labelKey = "ratio_landscape";
                        }
                        return DropdownMenuItem(
                          value: v,
                          child: Text(
                            generator.getLocaleString(lang, labelKey),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => aspectRatioStr = v!),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "${generator.getLocaleString(lang, "y_offset_label")}: ${yOffset.round()}",
                ),
                Slider(
                  value: yOffset,
                  min: -400,
                  max: 400,
                  divisions: 800,
                  label: yOffset.round().toString(),
                  onChanged: (v) => setState(() => yOffset = v),
                ),
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    InkWell(
                      onTap: () =>
                          setState(() => generateAudio = !generateAudio),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: generateAudio,
                            onChanged: (v) =>
                                setState(() => generateAudio = v!),
                          ),
                          Text(generator.getLocaleString(lang, "audio_label")),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    if (generateAudio) ...[
                      Text(generator.getLocaleString(lang, "gender_label")),
                      const SizedBox(width: 10),
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
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: _previewListenable,
                  builder: (context, child) {
                    return ElevatedButton.icon(
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
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        generator.getLocaleString(lang, "generate_btn"),
                      ),
                    );
                  },
                ),
                if (statusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Semantics(
                      liveRegion: true,
                      child: Row(
                        children: [
                          Icon(
                            isError
                                ? Icons.error
                                : (isSuccess ? Icons.check_circle : Icons.info),
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
                              style: TextStyle(
                                color: isError
                                    ? Theme.of(context).colorScheme.error
                                    : (isSuccess
                                          ? Colors.green
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
                if (altText.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    generator.getLocaleString(lang, "alt_text_label"),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(altText),
                  ElevatedButton.icon(
                    onPressed: () => _copyToClipboard(altText),
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(
                      generator.getLocaleString(lang, "copy_alt_text_btn"),
                    ),
                  ),
                ],
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    generator.getLocaleString(lang, "caption_label"),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(caption),
                  ElevatedButton.icon(
                    onPressed: () => _copyToClipboard(caption),
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(
                      generator.getLocaleString(lang, "copy_caption_btn"),
                    ),
                  ),
                ],
              ],
            ),
          );

          if (constraints.maxWidth > 800) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(child: formContent),
                ),
                Expanded(flex: 1, child: Center(child: previewWidget)),
              ],
            );
          } else {
            return SingleChildScrollView(
              child: Column(
                children: [
                  formContent,
                  const SizedBox(height: 20),
                  Center(child: previewWidget),
                  const SizedBox(height: 40),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
