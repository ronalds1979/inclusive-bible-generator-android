# Android Accessibility QA & Release Checklist

Use this checklist before every release alongside the automated test suite (`flutter test test/wcag_accessibility_guidelines_test.dart`).

## 1. Automated Verification (CI / Local)
- [ ] Run `flutter analyze` — zero issues in `lib/` and `test/`.
- [ ] Run `flutter test` — all unit, widget, and WCAG guideline tests pass across:
  - All 4 tabs (`Verse`, `Background`, `Style`, `Audio & Text`)
  - Light, Dark, and High-Contrast themes
  - `androidTapTargetGuideline` (≥ 48×48dp), `labeledTapTargetGuideline`, and `textContrastGuideline`
  - `2.0x` font scaling + narrow (`320×568`) and compact landscape (`720×360`) viewports
  - All 3 supported locales (`en`, `es`, `pt-BR`)

## 2. Android Accessibility Scanner
- [ ] Install **Google Accessibility Scanner** on a test device or emulator.
- [ ] Scan all 4 tabs (`Verse`, `Background`, `Style`, `Audio & Text`) in both Light and Dark themes.
- [ ] Scan modals: **Search Topic**, **Book Search**, **Full-Screen Preview (Vision Simulator)**, **Custom Color Picker**, **Advanced Features**, and **About & Credits**.
- [ ] Confirm **0 touch-target (<48dp)**, **0 missing-label**, **0 duplicate-label**, and **0 contrast** warnings.

## 3. TalkBack (Screen Reader)
- [ ] Navigate linearly across all 4 tabs using swipe right/left — confirm logical reading order and no focus traps.
- [ ] Switch TalkBack granularity to **Headings** — confirm every major section is reachable as a heading.
- [ ] Switch in-app language (`EN` ↔ `ES` ↔ `PT-BR`) — confirm Material semantics and status messages announce in the selected language.
- [ ] Focus the **Verse Preview Card** and open **TalkBack Actions** — confirm *Move text up*, *Move text down*, and *Center* work without dragging.
- [ ] Start **Listen Preview** in Step 4, switch to Step 1, and confirm the persistent **Stop Audio** banner is immediately focusable and stops TTS.

## 4. Voice Access
- [ ] Enable Android **Voice Access** and say *"Show labels"*.
- [ ] Confirm unique, unambiguous labels on every visible action (e.g., *"Clear reference"*, *"Clear Bible verse"*, *"Dismiss status message"*, *"Reset Spacing"*, *"Reset Tracking"*, *"Reset"*).
- [ ] Complete core flow by voice: select tab → enter/fetch verse → adjust style → generate/share.

## 5. Switch Access & Physical Keyboard
- [ ] Traverse with `Tab` / `Shift+Tab` (or 2-switch scan) — verify visible focus indicators on all interactive controls including background thumbnails and the preview card.
- [ ] Use `ArrowUp`, `ArrowDown`, and `Home` on the focused Verse Preview Card to reposition text.
- [ ] Open the **Custom Color** dialog, enter a hex value via keyboard, and verify `Escape` / Back reverts to the previous color.

## 6. Display Scaling & OS Preferences
- [ ] Set Android **Font Size = Largest (200%)** and **Display Size = Large** — verify zero clipping or horizontal overflow across all 4 tabs and dialogs.
- [ ] Enable Android **High Contrast Text / Color Correction** and **Remove Animations** — verify the app automatically switches to high-contrast styling and suppresses non-essential motion.
