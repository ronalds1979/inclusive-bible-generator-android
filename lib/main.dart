import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:gal/gal.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

import 'generator.dart';
import 'getbible_api.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Generator generator = Generator();
  final FlutterTts flutterTts = FlutterTts();
  final GlobalKey _globalKey = GlobalKey();

  String currentLang = "Português (Brasil)";
  List<String> languages = [
    "Português (Brasil)",
    "English (US/UK)",
    "Español (España)",
  ];

  List<String> bibleVersions = ["-"];
  String selectedBibleVersion = "-";
  Map<String, String> bibleVersionsMap = {};

  TextEditingController referenceController = TextEditingController();
  TextEditingController verseController = TextEditingController();

  String selectedBackground = "default.png";
  List<String> backgrounds = ["default.png"]; // Need to load from assets
  String? customImagePath;

  String fontColorStr = "#FFFFFF";
  Color fontColor = Colors.white;
  double fontSize = 60.0;
  String aspectRatioStr = "1:1";
  double yOffset = 0.0;

  bool generateAudio = false;
  String gender = "Female";
  List<String> genders = ["Female", "Male"];

  String altText = "";
  String caption = "";
  String statusMessage = "";

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await generator.loadLocales();
    await _loadBackgrounds();
    await _loadBibleVersions();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadBackgrounds() async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      backgrounds = manifestMap.keys
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
      print("Error loading backgrounds: \$e");
    }
  }

  String getLangKey() {
    if (currentLang.contains("English")) return "en";
    if (currentLang.contains("Español")) return "es";
    return "pt-BR";
  }

  Future<void> _loadBibleVersions() async {
    setState(() {
      statusMessage = "Loading Bible versions...";
    });
    String langCode = "pt";
    if (getLangKey() == "en") {
      langCode = "en";
    } else if (getLangKey() == "es") {
      langCode = "es";
    }

    var versions = await GetBibleAPI.getVersions(lang: langCode);
    if (versions.isNotEmpty) {
      bibleVersionsMap = {for (var v in versions) v["name"]!: v["id"]!};
      bibleVersions = bibleVersionsMap.keys.toList();
      selectedBibleVersion = bibleVersions.first;
      setState(() {
        statusMessage = "";
      });
    } else {
      setState(() {
        bibleVersions = ["-"];
        selectedBibleVersion = "-";
        statusMessage = "Error loading versions.";
      });
    }
  }

  Future<void> _fetchVerse() async {
    String reference = referenceController.text.trim();
    if (selectedBibleVersion == "-" || reference.isEmpty) {
      setState(() {
        statusMessage = "Please provide Version, and Reference.";
      });
      return;
    }

    String? bibleId = bibleVersionsMap[selectedBibleVersion];
    if (bibleId == null) return;

    setState(() {
      statusMessage = "Fetching verse...";
    });

    String? content = await GetBibleAPI.getPassage(
      bibleId,
      reference,
      lang: getLangKey(),
    );
    if (content != null) {
      setState(() {
        verseController.text = content;
        statusMessage = "Verse fetched successfully.";
      });
    } else {
      setState(() {
        statusMessage = "Error fetching verse. Check reference format.";
      });
    }
  }

  Future<void> _selectCustomImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        customImagePath = image.path;
      });
    }
  }

  Future<void> _generateContent() async {
    String verse = verseController.text.trim();
    String reference = referenceController.text.trim();

    if (verse.isEmpty || reference.isEmpty) return;

    setState(() {
      statusMessage = "Generating content...";
    });

    String lang = getLangKey();
    var texts = await generator.generateTexts(lang, verse, reference);
    setState(() {
      altText = texts["altText"]!;
      caption = texts["caption"]!;
    });

    String? audioPath;
    if (generateAudio) {
      audioPath = await _generateAudio(verse, reference, lang);
    }

    await _captureSaveAndShareImage(audioPath: audioPath);

    setState(() {
      statusMessage = generator.getLocaleString(lang, "success_msg");
    });
  }

  Future<String?> _generateAudio(
    String verse,
    String reference,
    String lang,
  ) async {
    await flutterTts.setLanguage(lang);
    if (gender == "Female") {
      await flutterTts.setVoice({
        "name": "pt-BR-FranciscaNeural",
        "locale": "pt-BR",
      });
    }

    String textToRead = "$reference. $verse";
    if (Platform.isAndroid) {
      String fileName =
          "verse_audio_${DateTime.now().millisecondsSinceEpoch}.wav";
      // flutter_tts synthesizeToFile saves to getExternalStorageDirectory on Android by default or getApplicationDocumentsDirectory
      // The file is saved internally and we need the path.
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        // synthesizeToFile only takes the filename, not the full path in older flutter_tts or takes the filename and prepends path.
        // Actually, in flutter_tts for android, synthesizeToFile saves to the external storage directory.
        await flutterTts.synthesizeToFile(textToRead, fileName);
        // Wait for file to exist
        await Future.delayed(const Duration(seconds: 2));
        return "${dir.path}/$fileName";
      }
    }
    return null;
  }

  Future<void> _captureSaveAndShareImage({String? audioPath}) async {
    try {
      RenderRepaintBoundary boundary =
          _globalKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = (await getApplicationDocumentsDirectory()).path;
      File imgFile = File(
        '$directory/verse_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await imgFile.writeAsBytes(pngBytes);

      // Save directly to the public gallery
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }
      await Gal.putImage(imgFile.path, album: 'Inclusive Bible');

      // Share image (and audio if generated)
      List<XFile> filesToShare = [XFile(imgFile.path)];
      if (audioPath != null && await File(audioPath).exists()) {
        filesToShare.add(XFile(audioPath));
      }

      await Share.shareXFiles(filesToShare, text: "$altText\n\n$caption");
    } catch (e) {
      print("Error capturing image: $e");
    }
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

  Widget _buildPreview() {
    double width = 300;
    double height = 300;
    if (aspectRatioStr == "3:4") {
      height = 400;
    } else if (aspectRatioStr == "4:3") {
      width = 400;
      height = 300;
    }

    return RepaintBoundary(
      key: _globalKey,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: customImagePath != null
                ? FileImage(File(customImagePath!)) as ImageProvider
                : AssetImage("assets/backgrounds/$selectedBackground"),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withAlpha(128),
              BlendMode.darken,
            ),
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Transform.translate(
                  offset: Offset(0, yOffset - 20),
                  child: Text(
                    verseController.text.isEmpty
                        ? "Preview Verse"
                        : verseController.text,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(
                      color: fontColor,
                      fontSize: fontSize / 2, // Scale down for preview
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(0, yOffset + (fontSize / 2) + 40),
                child: Text(
                  referenceController.text.isEmpty
                      ? "Reference"
                      : referenceController.text,
                  style: GoogleFonts.roboto(
                    color: fontColor,
                    fontSize: (fontSize * 0.66) / 2,
                  ),
                ),
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

    String lang = getLangKey();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          generator.getLocaleString(
            lang,
            "title",
            kwargs: {'title': 'Inclusive Bible Generator'},
          ),
        ),
        actions: [
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
          Widget formContent = Padding(
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
                    ElevatedButton(
                      onPressed: _fetchVerse,
                      child: Text(
                        generator.getLocaleString(lang, "fetch_verse_btn"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: referenceController,
                  decoration: InputDecoration(
                    labelText: generator.getLocaleString(
                      lang,
                      "reference_label",
                    ),
                  ),
                  onChanged: (v) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: verseController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: generator.getLocaleString(lang, "verse_label"),
                  ),
                  onChanged: (v) => setState(() {}),
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
                      }),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _selectCustomImage,
                      child: Text(
                        generator.getLocaleString(lang, "custom_image_btn"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Text(generator.getLocaleString(lang, "font_color_label")),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: fontColor,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Pick a color!'),
                              content: SingleChildScrollView(
                                child: ColorPicker(
                                  pickerColor: fontColor,
                                  onColorChanged: (c) =>
                                      setState(() => fontColor = c),
                                ),
                              ),
                              actions: <Widget>[
                                ElevatedButton(
                                  child: const Text('Got it'),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: const Text(
                        "Select Color",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  generator.getLocaleString(lang, "font_size_label") +
                      ": $fontSize",
                ),
                Slider(
                  value: fontSize,
                  min: 20,
                  max: 120,
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
                      items: ["1:1", "3:4", "4:3"]
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => aspectRatioStr = v!),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  generator.getLocaleString(lang, "y_offset_label") +
                      ": $yOffset",
                ),
                Slider(
                  value: yOffset,
                  min: -400,
                  max: 400,
                  onChanged: (v) => setState(() => yOffset = v),
                ),
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Checkbox(
                      value: generateAudio,
                      onChanged: (v) => setState(() => generateAudio = v!),
                    ),
                    Text(generator.getLocaleString(lang, "audio_label")),
                    const SizedBox(width: 20),
                    if (generateAudio) ...[
                      Text(generator.getLocaleString(lang, "gender_label")),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: gender,
                        items: genders
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => gender = v!),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _generateContent,
                  child: Text(generator.getLocaleString(lang, "generate_btn")),
                ),
                if (statusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      statusMessage,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                if (altText.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    "Alt-Text:",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(altText),
                  ElevatedButton(
                    onPressed: () => _copyToClipboard(altText),
                    child: Text(
                      generator.getLocaleString(lang, "copy_alt_text_btn"),
                    ),
                  ),
                ],
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    "Caption:",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(caption),
                  ElevatedButton(
                    onPressed: () => _copyToClipboard(caption),
                    child: Text(
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
                Expanded(flex: 1, child: Center(child: _buildPreview())),
              ],
            );
          } else {
            return SingleChildScrollView(
              child: Column(
                children: [
                  formContent,
                  const SizedBox(height: 20),
                  Center(child: _buildPreview()),
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
