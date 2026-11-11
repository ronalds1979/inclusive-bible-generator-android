# Inclusive Bible Generator

A cross-platform Flutter application for generating accessible, shareable Bible verse graphics, social media captions, screen-reader alt-text, and text-to-speech (TTS) audio in Portuguese (`pt-BR`), English (`en`), and Spanish (`es`).

## Features

- **Multi-language Support**: Portuguese (Brazil), English (US/UK), and Spanish (Spain).
- **Bible Verse Lookup**: Fetches passages directly from the [GetBible v2 API](https://api.getbible.net/v2).
- **AI Background Generation (Gemini)**: Connect your Gemini API Key (Google AI Studio) to generate custom background images aligned with your chosen Bible verse using `gemini-nano-banana-2.1` via the Gemini Interactions API, with selectable visual styles and aspect ratios.
- **Accessible Content Generation**: Automatically produces screen-reader descriptions (`Alt-Text` / `#PraCegoVer`) and formatted social media captions.
- **Customizable Graphics**: Choose built-in, gallery, or Gemini-generated backgrounds, aspect ratios (`1:1`, `3:4`, `4:3`), font sizes, colors, and vertical offset.
- **Audio Synthesis (TTS)**: Optional text-to-speech audio generation on Android.
- **Export & Share**: Saves generated images to the device gallery and shares via native share sheets.
