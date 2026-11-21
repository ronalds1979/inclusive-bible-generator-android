# Inclusive Bible Generator

A free, accessibility-first Flutter application for Android (API 26+) that helps you create ready-to-share Bible verse graphics, screen-reader alternative text (Alt-Text), social media captions, and Text-to-Speech (TTS) audio narration with word-highlighted live transcripts in English (`EN-US`), Portuguese (`PT-BR`), and Spanish (`ES-ES`).

## Key Features

- **Ready to Share on Launch (Verse of the Day)**: Automatically loads the Verse of the Day when the app opens (and reloads it when switching Bible languages)—pre-populating the verse, reference, live preview, Alt-Text, and caption immediately.
- **Guided 4-Step Workflow**: Step-by-step navigation across **1. Verse**, **2. Background**, **3. Style**, and **4. Audio & Text**, with a live-announced progress bar, Back/Next controls, compact `EN-US` / `PT-BR` / `ES-ES` language selector, and an **About & Credits** dialog crediting the YouVersion Platform.
- **Smart Bible Picker, Topic Search & Voice Input**:
  - Searchable Bible book selector, dynamic chapter, verse, and verse-range dropdowns, and per-language Bible version preference persistence (`preferred_bible_versions.json`).
  - **Keyword, Phrase & Theme Search**: Tap **Search Topic** to find Bible verses by word, phrase, or 1-tap theme chips (`Peace`, `Hope`, `Love`, `Strength`, `Faith`) via Bolls.life's keyless semantic search.
  - **Hands-Free Voice-to-Verse Input**: Tap the microphone button on supported Android devices to speak a reference (e.g., *"Psalm 23 verse 1"* or *"Salmos 23 versículo 1"*) using Android's built-in speech recognizer.
  - Transparent multi-source Bible lookup powered by the [YouVersion Platform API](https://platform.youversion.com/) (configured transparently at build time—no user API key prompt), [Bolls.life](https://bolls.life/), and [GetBible v2 API](https://api.getbible.net/v2).
- **Accessible Backgrounds & Pixel-Sampled Contrast**:
  - Curated built-in backgrounds, **Gallery Picker** for custom photos (validated up to 20 MB), and plain-language **Background Tone Badges** (`Dark` / `Light` / `Medium`).
  - **Background Dim (Contrast)** slider (`0%`–`75%`) with `48×48 dp` `-` / `+` stepper buttons.
  - **Live WCAG 2.1 Contrast Badge (`AA` / `AAA`) & Smart Placement**: Samples actual photo pixels across top, center, and bottom bands to verify real contrast, offers 1-tap **Auto-Dim**, and suggests **Best Position** when another area of the photo has higher contrast.
- **Rich Offline Typography & Editorial Layout**:
  - **8 Offline Typefaces**: Bundled **Playfair Display**, **Lora**, and **Montserrat** (Regular, Bold, Italic, BoldItalic) plus **Modern Sans**, **Classic Serif**, **Condensed**, **Script**, and **Typewriter**—with live preview on every chip.
  - **Full Formatting & Accents**: **Bold** & **Italic** toggles, **Left / Center / Right** alignment, luminance-aware **Text Shadows** (`None`, `Soft`, `Strong`), **Text Backdrops** (`None`, `Frosted Card`, `High Contrast`), **Card Accents** (`None`, `Divider Line`, `Inset Frame`), **Line Spacing** (`1.00x`–`2.00x`), **Font Size** (`20`–`120`), and **Vertical Position**—all persisted to `typography_style.json`.
  - **Quick Style Presets**: 1-tap **Classic Editorial**, **Modern Minimal**, **Frosted Devotional**, **Max Contrast (WCAG)**, and **Dyslexia-Friendly** presets, plus **Reset Style**.
  - Aspect ratios: `1:1` (Square), `3:4` (Portrait), `9:16` (Story), and `4:3` (Landscape), with an **Expandable Full-Screen Preview** featuring a **Vision Preview Simulator** (`Normal`, `Protanopia`, `Deuteranopia`, `Tritanopia`, `Grayscale`, and `Low Vision` blur).
- **Audio Narration (TTS), Word-Highlighted Captions & Alt-Text**:
  - Preview and export spoken audio on Android in **Female** or **Male** device voices with natural spoken Bible references and documentary-style pacing.
  - **Word-Highlighted Live Transcript**: Highlights each spoken word live in the Audio Transcript card during playback.
  - **Editable Alt-Text, Captions & Inclusivity Scorecard**: Edit the background image description inline (or generate it on-device with Gemini Nano), copy structured `#PraCegoVer` / `#ParaTodosVerem` Alt-Text and social captions in one tap, and review the **Inclusivity Readiness (`4/4`)** scorecard before sharing.
- **Optional Zero-Cost Advanced Features** (accessible via the **Advanced Features** dialog, persisted in `advanced_features.json`):
  - **On-Device Alt-Text (Gemini Nano)**: Automatically checks device compatibility via Android's ML Kit GenAI Image Description API; offered only on compatible AICore devices—100% free, offline, and no API key required.
  - **Continue in Gemini App**: Sends ready-made localized background or devotional caption prompts directly to the user's own free Gemini app with zero API key or cost.
  - **High-Contrast App Theme** and **Color-Blind-Friendly Status Colors** (Blue/Amber instead of Red/Green).

## Accessibility & Inclusive Design

Inclusive Bible Generator is built with empathy for people with visual, color-vision, hearing, motor, and cognitive disabilities:

### Visual Disabilities & Color Blindness (Dyschromatopsia)
- **Screen Reader (TalkBack) Support**: `Semantics(header: true)` section headings, live-region announcements for contrast warnings, script legibility tips, and status updates, decorative `ExcludeSemantics` icons, and unified semantic descriptions for the live verse preview.
- **Color-Blindness (CVD) First**: Always-visible named color chips (including **Deep Navy**), live plain-language color naming inside the custom color picker, **CVD-Aware WCAG Contrast Checks** across Protanopia/Deuteranopia/Tritanopia, 1-tap **Suggest Safe Color**, plain-language **Background Tone Badges**, an optional **Color-Blind-Friendly Status Colors** palette, and a **Vision Preview Simulator** in full-screen preview.
- **Low Vision & Dynamic Text Scaling**: Optional **High-Contrast App Theme**, **Expandable Full-Screen Preview**, overflow-safe Material 3 controls, and scalable typography.

### Hearing Disabilities (Deaf & Hard of Hearing)
- **Word-Highlighted Captions & Transcripts**: Full readable **Audio Transcript** with real-time word highlighting during playback, plus a live visual **Playing Audio (Captions)** indicator.
- **Tactile & Visual Alerts**: Status updates, errors, copy confirmations, and preview toggles pair visual banners/icons with `HapticFeedback`.

### Motor, Switch Access & Cognitive Support
- **`48×48 dp` Steppers on Every Slider**: Dedicated `-` / `+` and `Up` / `Down` buttons flank **Background Dim**, **Line Spacing**, **Font Size**, and **Vertical Position** so no adjustment requires dragging a slider thumb.
- **Hands-Free & Low-Effort Input**: Voice-to-Verse microphone input, 1-tap theme search chips, and 1-tap Quick Style Presets (including **Dyslexia-Friendly** and a contextual legibility tip for long verses in Script).
- **Keyboard, D-Pad & Switch Access**: `FocusTraversalGroup` with `ReadingOrderTraversalPolicy` and `48×48 dp` minimum touch targets across all interactive controls.

## Getting Started

1. Ensure [Flutter](https://docs.flutter.dev/get-started/install) (`^3.11.0` Dart SDK) and Android SDK (API 26+) are installed.
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run tests and static analysis:
   ```bash
   flutter test
   flutter analyze
   ```
4. Run or build with your YouVersion Platform API key injected transparently at build time:
   ```bash
   flutter run --dart-define=YOUVERSION_API_KEY=YOUR_KEY
   flutter build apk --release --dart-define=YOUVERSION_API_KEY=YOUR_KEY
   ```

## Acknowledgments

Special thanks to **[YouVersion](https://platform.youversion.com/)** for sharing the YouVersion Platform API that brings Bible books, translations, passages, and the daily Verse of the Day to this app—helping make Scripture accessible to everyone. Additional Scripture and search support is powered by [Bolls.life](https://bolls.life/) and [GetBible v2](https://api.getbible.net/v2).
