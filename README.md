# Inclusive Bible Generator

A Flutter application for Android (and cross-platform) that helps you create accessible, ready-to-share Bible verse graphics, screen-reader alternative text (Alt-Text), social media captions, and Text-to-Speech (TTS) audio narration with live transcripts in English (`en`), Portuguese (`pt-BR`), and Spanish (`es`).

## Key Features

- **Ready to Share on Launch (Verse of the Day)**: Automatically loads the Verse of the Day when the app opens (and reloads it when switching Bible languages)—pre-populating the verse, reference, live preview, Alt-Text, and caption—so you have accessible content ready to share immediately.
- **Guided 4-Step Workflow**: Step-by-step navigation across **1. Verse**, **2. Background**, **3. Style**, and **4. Audio & Text**, with a live-announced progress bar and Back/Next controls.
- **Smart Bible Picker & Version Memory**: Searchable Bible book selector, dynamic chapter, verse, and verse-range dropdowns that automatically fetch the selected passage, per-language Bible version preference persistence (`preferred_bible_versions.json`), device-locale language detection, and multi-source Bible lookup ([YouVersion Platform API](https://platform.youversion.com/), [Bolls.life](https://bolls.life/), and [GetBible v2 API](https://api.getbible.net/v2)).
- **Accessible Backgrounds & Contrast**:
  - Curated built-in backgrounds with selection checkmarks and descriptive labels.
  - **Free Stock Photos** search with mood presets (Sunrise, Ocean, Mountains, Stars, Forest) and keyword search.
  - **Gallery Picker** for custom photos (validated up to 20 MB).
  - **Background Dim (Contrast)** slider (`0%`–`75%`) to darken busy backgrounds so text remains legible.
  - **Experimental AI Background (Gemini)**: Optional toggle to connect your own Gemini API key (stored encrypted on-device via `flutter_secure_storage`) and generate custom artwork.
- **Customizable Typography & Layout**:
  - Aspect ratios: `1:1` (Square), `3:4` (Portrait), `9:16` (Story), and `4:3` (Landscape).
  - Default font size `22` (adjustable from `20` to `120`), high-contrast color swatches, custom color picker, adaptive non-overlapping verse/reference layout (`VersePreviewCard`), and vertical positioning via both a slider (with a **Center** reset button) and drag-on-preview.
- **Audio Narration (TTS) & Transcripts**:
  - Preview and export spoken audio on Android in **Female** or **Male** voices using installed device TTS voices (with a deeper pitch fallback if no dedicated male voice pack is installed).
  - Natural spoken Bible references (e.g., `"chapter 4, verse 11"` instead of clock time) and documentary-style pacing.
  - **Live Audio Transcript & Visual Captions**: Displays the exact spoken script on screen and highlights a live **Playing Audio (Captions)** banner during playback.
- **Alt-Text, Captions & Export**:
  - Automatically generates structured screen-reader Alt-Text (`#PraCegoVer` / `#ParaTodosVerem` in Portuguese) and social media captions with one-tap copy buttons.
  - Saves graphics to the device gallery and shares images, text, and audio via the native share sheet.

## Accessibility & Inclusive Design

Inclusive Bible Generator is designed to work for everyone, including people with visual, hearing, motor, and cognitive disabilities:

### Visual Disabilities (Blindness & Low Vision)
- **Screen Reader (TalkBack) Support**: Meaningful labels and `Semantics` on controls, live-region announcements for step progress and status messages, and a unified semantic description for the live verse preview card. Decorative icons are excluded from the semantics tree and paired icon-text rows are grouped with `MergeSemantics`.
- **High Color Contrast**: Light and dark themes use accessible contrast ratios for text, icons, and status indicators, never relying on color alone (e.g., checkmarks on selected swatches and backgrounds, icons paired with error/success banners).
- **Dynamic Text Scaling**: Uses scalable Material typography and flexible containers without cramped fixed-height bars so text scales cleanly with system font size settings.

### Hearing Disabilities (Deaf & Hard of Hearing)
- **Visual Captions & Transcripts**: Full readable **Audio Transcript** displayed directly in the Audio & Text tab, plus a live visual **Playing Audio (Captions)** indicator during preview playback.
- **Tactile & Visual Alerts**: Status updates, errors, copy confirmations, and audio preview toggles pair visual banners/icons with `HapticFeedback` so no information is conveyed by sound alone.
- **System Audio Compatibility**: Device TTS playback uses standard Android audio streams and respects system Mono Audio settings.

### Motor & Flexible Input
- **Large Touch Targets**: Interactive buttons, chips, swatches, checkboxes, and dropdowns meet the `48×48 dp` minimum touch target guideline.
- **Keyboard, D-Pad & Switch Access**: Uses `FocusTraversalGroup` with `ReadingOrderTraversalPolicy`, plus slider/button alternatives for drag-on-preview text positioning.

## Getting Started

1. Ensure [Flutter](https://docs.flutter.dev/get-started/install) (`^3.11.0` Dart SDK) is installed.
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run tests and static analysis:
   ```bash
   flutter test
   flutter analyze
   ```
4. Run on an Android device or emulator:
   ```bash
   flutter run
   ```

## Acknowledgments

Special thanks to **[YouVersion](https://platform.youversion.com/)** for the YouVersion Platform API providing access to Bible books, translations, and verses that help make Scripture accessible to everyone. Additional Scripture and media support is powered by [Bolls.life](https://bolls.life/) and [GetBible v2](https://api.getbible.net/v2).
