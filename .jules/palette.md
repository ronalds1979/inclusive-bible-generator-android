## 2024-05-18 - Added Loading States to Async Buttons

**Learning:** Missing loading indicators for async operations (fetching verses, generating content) in this app causes confusion, as the user might click the buttons multiple times.

**Action:** Add visual loading feedback to buttons (like `CircularProgressIndicator` instead of text, and disable the button while loading) for all operations that involve networking or heavy local processing.

## 2026-10-28 - Dynamic Color Contrast for Color Pickers
**Learning:** Hardcoding text colors (like black) on dynamic colored backgrounds (like a color picker button) causes severe WCAG contrast violations when dark colors are selected.
**Action:** Use `.computeLuminance()` on the selected color to dynamically switch between black and white text, ensuring accessible contrast ratios regardless of user selection.
